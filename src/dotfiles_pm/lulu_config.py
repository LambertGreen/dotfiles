#!/usr/bin/env python3
"""LuLu (Objective-See firewall) config as reviewable text: snapshot + drift check.

LuLu keeps its state in a root-owned, world-readable directory that its system
extension owns. We never write there. Instead:

  rules        rules.plist is a binary NSKeyedArchiver blob. We decode it into the
               exact JSON shape LuLu's own "Rules → Export..." writes (Rule.toJSON in
               objective-see/LuLu), so restoring is LuLu's own "Rules → Import...".
  preferences  preferences.plist is plain XML; we snapshot the settings that
               matter (minus volatile UI state) as sorted JSON. LuLu has no
               prefs import, so restore prints which toggles to flip in Settings.

Stdlib only: runs on a fresh Mac with the system python3.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import plistlib
import sys
from pathlib import Path
from typing import Any

LULU_DIR = Path("/Library/Objective-See/LuLu")
LIVE_RULES = LULU_DIR / "rules.plist"
LIVE_PREFS = LULU_DIR / "preferences.plist"

# consts.h: RULE_TYPE_*
RULE_TYPE_USER = 3
RULE_TYPE_NAMES = {0: "default", 1: "apple", 2: "baseline", 3: "user", 4: "passive", 5: "recent"}

# Keys LuLu's Rule.toJSON emits (and Rule.initFromJSON reads). Order is irrelevant:
# we sort keys on output so diffs are stable.
RULE_FIELDS = (
    "key", "uuid", "path", "name", "endpointAddr", "endpointHost", "creation",
    "expiration", "endpointPort", "isEndpointAddrRegex", "type", "isDisabled",
    "scope", "action", "csInfo",
)
# Optional in toJSON: omitted when nil.
OPTIONAL_RULE_FIELDS = {"endpointHost", "creation", "expiration", "isDisabled", "csInfo"}
NUMERIC_RULE_FIELDS = {"type", "scope", "action", "isDisabled", "isEndpointAddrRegex"}

# Preferences that change on their own (install stamp, last alert choice). Not config.
VOLATILE_PREFS = {"installTime", "alertLastRuleDuration", "alertLastRuleScope"}

NS_EPOCH = dt.datetime(2001, 1, 1, tzinfo=dt.timezone.utc)
# LuLu's NSDateFormatter pattern "yyyy-MM-dd'T'HH:mm:ssZ"; we pin UTC for stable output.
LULU_DATE_FMT = "%Y-%m-%dT%H:%M:%S+0000"


# ── NSKeyedArchiver decoding ─────────────────────────────────────────────────


class _Unarchiver:
    """Resolve an NSKeyedArchiver object graph into plain Python values."""

    def __init__(self, archive: dict[str, Any]):
        if archive.get("$archiver") != "NSKeyedArchiver":
            raise ValueError("not an NSKeyedArchiver plist")
        self.objects = archive["$objects"]
        self.top = archive["$top"]

    def root(self) -> Any:
        return self.resolve(self.top["root"])

    def resolve(self, ref: Any) -> Any:
        if isinstance(ref, plistlib.UID):
            return self.decode(self.objects[ref.data])
        return self.decode(ref)

    def decode(self, obj: Any) -> Any:
        if obj == "$null":
            return None
        if not isinstance(obj, dict) or "$class" not in obj:
            return obj
        classname = self.objects[obj["$class"].data]["$classname"]
        if classname in ("NSDictionary", "NSMutableDictionary"):
            keys = [self.resolve(k) for k in obj["NS.keys"]]
            return {k: self.resolve(v) for k, v in zip(keys, obj["NS.objects"])}
        if classname in ("NSArray", "NSMutableArray", "NSSet", "NSMutableSet"):
            return [self.resolve(v) for v in obj["NS.objects"]]
        if classname in ("NSString", "NSMutableString"):
            return obj["NS.string"]
        if classname == "NSDate":
            return NS_EPOCH + dt.timedelta(seconds=obj["NS.time"])
        # Any other archived class (LuLu's Rule): its encoded fields, resolved.
        return {k: self.resolve(v) for k, v in obj.items() if k != "$class"}


def load_archived_rules(path: Path) -> dict[str, Any]:
    with path.open("rb") as fh:
        root = _Unarchiver(plistlib.load(fh)).root()
    if not isinstance(root, dict):
        raise ValueError(f"unexpected rules root: {type(root).__name__}")
    return root


# ── LuLu export JSON ─────────────────────────────────────────────────────────


def _json_scalar(value: Any) -> Any:
    # toJSON writes NSNumbers via intValue, so bools become 0/1.
    if isinstance(value, bool):
        return int(value)
    if isinstance(value, dt.datetime):
        return value.astimezone(dt.timezone.utc).strftime(LULU_DATE_FMT)
    return value


def _cs_info(cs: dict[str, Any]) -> dict[str, Any]:
    out: dict[str, Any] = {}
    for k, v in cs.items():
        if isinstance(v, list):
            out[k] = sorted(str(_json_scalar(i)) for i in v)
        elif isinstance(v, (str, int, float, bool)):
            out[k] = _json_scalar(v)
    return out


def rule_to_json(rule: dict[str, Any]) -> dict[str, Any]:
    """Mirror Rule.toJSON: same keys, same scalar types."""
    out: dict[str, Any] = {}
    for field in RULE_FIELDS:
        value = rule.get(field)
        if value is None and field in OPTIONAL_RULE_FIELDS:
            continue
        if field == "csInfo":
            out[field] = _cs_info(value or {})
        elif field in NUMERIC_RULE_FIELDS:
            out[field] = int(value or 0)  # [nil intValue] == 0
        else:
            out[field] = _json_scalar("" if value is None else value)
    return out


def _rule_sort_key(rule: dict[str, Any]) -> tuple:
    return (
        rule.get("endpointAddr", ""), rule.get("endpointPort", ""),
        rule.get("action", 0), rule.get("path", ""), rule.get("uuid", ""),
    )


def to_lulu_export(archived: dict[str, Any], user_only: bool = True) -> dict[str, list[dict]]:
    """Same filtering as LuLu's RulesMenuController.exportRules.

    Temporary rules (bound to a pid) are never exported. With user_only, only
    RULE_TYPE_USER rules: LuLu's Import then *merges* (replaces only user rules)
    instead of replacing the whole rule set.
    """
    export: dict[str, list[dict]] = {}
    for key in sorted(archived):
        entry = archived[key] or {}
        rules = [
            r for r in entry.get("rules") or []
            if r.get("pid") is None and (not user_only or r.get("type") == RULE_TYPE_USER)
        ]
        if rules:
            export[key] = sorted((rule_to_json(r) for r in rules), key=_rule_sort_key)
    return export


# ── Preferences ──────────────────────────────────────────────────────────────


def _portable(value: Any, home: str) -> Any:
    # allowList/blockList hold absolute paths; never commit a user's home dir.
    if isinstance(value, str) and home and (value == home or value.startswith(home + "/")):
        return "$HOME" + value[len(home):]
    if isinstance(value, dt.datetime):
        return _json_scalar(value)
    return value


def load_prefs(path: Path, home: str | None = None) -> dict[str, Any]:
    home = str(Path.home()) if home is None else home
    with path.open("rb") as fh:
        prefs = plistlib.load(fh)
    return {k: _portable(v, home) for k, v in sorted(prefs.items()) if k not in VOLATILE_PREFS}


# ── Output / comparison ──────────────────────────────────────────────────────


def dumps(data: Any) -> str:
    return json.dumps(data, indent=2, sort_keys=True, ensure_ascii=False) + "\n"


def write_if_changed(path: Path, text: str) -> bool:
    if path.exists() and path.read_text(encoding="utf-8") == text:
        return False
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")
    return True


def diff_rules(snapshot: dict[str, list], live: dict[str, list]) -> list[str]:
    """Summarise drift by rule identity (uuid), not by content dump."""
    def index(export: dict[str, list]) -> dict[str, dict]:
        return {r["uuid"]: r for rules in export.values() for r in rules}

    snap, cur = index(snapshot), index(live)
    lines = []
    for uuid in sorted(cur.keys() - snap.keys()):
        lines.append(f"+ {cur[uuid]['key']}  {cur[uuid]['endpointAddr']}:{cur[uuid]['endpointPort']}")
    for uuid in sorted(snap.keys() - cur.keys()):
        lines.append(f"- {snap[uuid]['key']}  {snap[uuid]['endpointAddr']}:{snap[uuid]['endpointPort']}")
    for uuid in sorted(snap.keys() & cur.keys()):
        if snap[uuid] != cur[uuid]:
            lines.append(f"~ {cur[uuid]['key']}  {cur[uuid]['endpointAddr']}:{cur[uuid]['endpointPort']}")
    return lines


def diff_prefs(snapshot: dict[str, Any], live: dict[str, Any]) -> list[str]:
    lines = []
    for k in sorted(snapshot.keys() | live.keys()):
        if snapshot.get(k) != live.get(k):
            lines.append(f"{k}: live={json.dumps(live.get(k))} snapshot={json.dumps(snapshot.get(k))}")
    return lines


def _count_by_type(archived: dict[str, Any]) -> str:
    counts: dict[str, int] = {}
    for entry in archived.values():
        for r in (entry or {}).get("rules") or []:
            name = RULE_TYPE_NAMES.get(r.get("type"), str(r.get("type")))
            counts[name] = counts.get(name, 0) + 1
    return ", ".join(f"{k} {v}" for k, v in sorted(counts.items()))


# ── CLI ──────────────────────────────────────────────────────────────────────


def cmd_export(args: argparse.Namespace) -> int:
    archived = load_archived_rules(args.live_rules)
    export = to_lulu_export(archived, user_only=not args.all)
    n = sum(len(v) for v in export.values())
    changed = write_if_changed(args.rules_out, dumps(export))
    print(f"rules: {n} {'all' if args.all else 'user'} rules from {len(export)} items "
          f"→ {args.rules_out} ({'updated' if changed else 'unchanged'}) [live: {_count_by_type(archived)}]")
    changed = write_if_changed(args.prefs_out, dumps(load_prefs(args.live_prefs)))
    print(f"prefs: → {args.prefs_out} ({'updated' if changed else 'unchanged'})")
    return 0


def cmd_check(args: argparse.Namespace) -> int:
    drift = False
    if args.prefs_snapshot.exists():
        lines = diff_prefs(json.loads(args.prefs_snapshot.read_text()), load_prefs(args.live_prefs))
        print(f"prefs: {'DRIFT' if lines else 'in sync'} ({args.prefs_snapshot})")
        for line in lines:
            print(f"  {line}")
        drift |= bool(lines)
    else:
        print(f"prefs: no snapshot at {args.prefs_snapshot} (run: just lulu-export)")
        drift = True

    if args.rules_snapshot.exists():
        snapshot = json.loads(args.rules_snapshot.read_text())
        # Compare like with like: a user-only snapshot vs live user rules.
        user_only = all(r.get("type") == RULE_TYPE_USER for rs in snapshot.values() for r in rs)
        live = to_lulu_export(load_archived_rules(args.live_rules), user_only=user_only)
        lines = diff_rules(snapshot, live)
        print(f"rules: {'DRIFT' if lines else 'in sync'} ({len(lines)} changed; {args.rules_snapshot})")
        for line in lines[: args.max_lines]:
            print(f"  {line}")
        if len(lines) > args.max_lines:
            print(f"  … {len(lines) - args.max_lines} more")
        drift |= bool(lines)
    else:
        print(f"rules: no snapshot at {args.rules_snapshot} (skipped; run: just lulu-export)")
    return 1 if drift else 0


def cmd_restore_steps(args: argparse.Namespace) -> int:
    """Print the supported restore path. Changes nothing."""
    print("LuLu restore (LuLu owns its files; everything goes through its UI):\n")
    if args.rules_snapshot.exists():
        snapshot = json.loads(args.rules_snapshot.read_text())
        n = sum(len(v) for v in snapshot.values())
        user_only = all(r.get("type") == RULE_TYPE_USER for rs in snapshot.values() for r in rs)
        mode = ("merge: replaces only your user-created rules" if user_only
                else "FULL replace: every existing rule is replaced")
        print(f"1. Rules ({n} rules, {mode})")
        print("   LuLu menu-bar icon → Rules → Import... → choose:")
        print(f"   {args.rules_snapshot}")
    else:
        print(f"1. Rules: no snapshot at {args.rules_snapshot}; skip (set LULU_RULES_SNAPSHOT).")

    if args.prefs_snapshot.exists():
        want = json.loads(args.prefs_snapshot.read_text())
        live = load_prefs(args.live_prefs) if args.live_prefs.exists() else {}
        lines = diff_prefs(want, live)
        print("\n2. Settings (LuLu menu-bar icon → Settings…):")
        if not lines:
            print("   already match the snapshot.")
        for k in sorted(want):
            if want.get(k) != live.get(k):
                target = want[k]
                if isinstance(target, str) and target.startswith("$HOME"):
                    target = str(Path.home()) + target[len("$HOME"):]
                print(f"   {k}: set to {json.dumps(target)} (now {json.dumps(live.get(k))})")
    else:
        print(f"\n2. Settings: no snapshot at {args.prefs_snapshot}.")
    return 0


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--live-rules", type=Path, default=LIVE_RULES)
    p.add_argument("--live-prefs", type=Path, default=LIVE_PREFS)
    sub = p.add_subparsers(dest="cmd", required=True)

    e = sub.add_parser("export", help="snapshot live rules + prefs as JSON")
    e.add_argument("--rules-out", type=Path, required=True)
    e.add_argument("--prefs-out", type=Path, required=True)
    e.add_argument("--all", action="store_true",
                   help="all non-temporary rules (Import then REPLACES everything), not just user rules")
    e.set_defaults(func=cmd_export)

    for name, func, help_ in (
        ("check", cmd_check, "report drift between live config and snapshots (exit 1 on drift)"),
        ("restore-steps", cmd_restore_steps, "print the LuLu UI steps that restore the snapshots"),
    ):
        c = sub.add_parser(name, help=help_)
        c.add_argument("--rules-snapshot", type=Path, required=True)
        c.add_argument("--prefs-snapshot", type=Path, required=True)
        c.add_argument("--max-lines", type=int, default=20)
        c.set_defaults(func=func)
    return p


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        return args.func(args)
    except FileNotFoundError as exc:
        print(f"lulu: {exc.filename}: not found (is LuLu installed?)", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
