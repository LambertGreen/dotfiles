#!/usr/bin/env python3
"""
herdr upgrade guard: keep `brew upgrade` from bumping herdr under a live server.

Background (2026-10-03, ai_council backlog #3): `just upgrade` ran a bare
`brew upgrade`. It took the herdr client from 0.8.2 (protocol 20) to 0.9.3
(protocol 22), while the running server stayed on protocol 20. After that,
every herdr call failed until `herdr server stop`, and stopping the server
closes every pane. That includes the Council's.

Homebrew cannot tell us a release's protocol before it is installed, so the
guard treats ANY herdr version change as a possible protocol bump. When a herdr
server is live, the routine upgrade leaves herdr out and says so loudly. It
points at the deliberate path, `just herdr-upgrade`, which restarts the server
on purpose. herdr is never pinned, so the hold cannot go silently stale: every
`just upgrade` names the version it held back.

Subcommands (herdr and brew are looked up on PATH, so tests stub them):
    brew-upgrade    Run `brew upgrade`, holding herdr back while a server is live
    status          Print the herdr upgrade picture (installed, candidate, live sessions)
    live-sessions   Print the names of running herdr sessions, one per line
"""

import json
import os
import shutil
import subprocess
import sys
from typing import Any, Dict, List, Optional

FORMULA = 'herdr'
DELIBERATE_PATH = 'just herdr-upgrade'


def _run_json(argv: List[str]) -> Optional[Any]:
    """Run argv and parse stdout as JSON; None on any failure."""
    try:
        result = subprocess.run(argv, capture_output=True, text=True, timeout=600)
    except (OSError, subprocess.TimeoutExpired):
        return None
    if result.returncode != 0:
        return None
    out = result.stdout
    # brew may print auto-update chatter before the JSON document.
    start = out.find('{')
    if start < 0:
        return None
    try:
        return json.loads(out[start:])
    except json.JSONDecodeError:
        return None


def live_sessions() -> Optional[List[str]]:
    """Names of running herdr sessions; [] if herdr is absent, None if unknown."""
    if not shutil.which('herdr'):
        return []
    data = _run_json(['herdr', 'session', 'list', '--json'])
    if not isinstance(data, dict) or not isinstance(data.get('sessions'), list):
        return None
    return [s['name'] for s in data['sessions'] if s.get('running')]


def skewed_sessions(sessions: List[str]) -> List[str]:
    """Live sessions whose server already speaks a different protocol than the client."""
    skewed = []
    for name in sessions:
        data = _run_json(['herdr', '--session', name, 'status', 'server', '--json'])
        if isinstance(data, dict) and data.get('compatible') is False:
            skewed.append(name)
    return skewed


def brew_outdated() -> Optional[Dict[str, Any]]:
    """`brew outdated --json=v2`, or None if brew could not answer."""
    data = _run_json(['brew', 'outdated', '--json=v2'])
    if not isinstance(data, dict):
        return None
    return data


def plan() -> Dict[str, Any]:
    """Decide what the routine upgrade should do about herdr.

    action:
      'upgrade-all'  no live herdr server: a plain `brew upgrade` is safe
      'hold'         a server is live (or we cannot tell): upgrade `targets`,
                     the outdated set minus herdr and pinned entries
      'error'        a server may be live and brew could not list outdated
                     packages, so we cannot build a safe target list
    """
    sessions = live_sessions()
    result: Dict[str, Any] = {
        'live_sessions': sessions,
        'skewed_sessions': [],
        'herdr_installed': None,
        'herdr_candidate': None,
        'targets': [],
    }
    if sessions == []:
        result['action'] = 'upgrade-all'
        return result
    if sessions:
        result['skewed_sessions'] = skewed_sessions(sessions)

    outdated = brew_outdated()
    if outdated is None:
        result['action'] = 'error'
        return result

    targets = []
    for kind in ('formulae', 'casks'):
        for entry in outdated.get(kind) or []:
            if kind == 'formulae' and entry.get('name') == FORMULA:
                installed = entry.get('installed_versions') or []
                result['herdr_installed'] = installed[-1] if installed else None
                result['herdr_candidate'] = entry.get('current_version')
                continue
            if entry.get('pinned'):
                continue
            targets.append(entry['name'])
    result['targets'] = targets
    result['action'] = 'hold'
    return result


def _sessions_label(sessions: Optional[List[str]]) -> str:
    if sessions is None:
        return 'unknown (`herdr session list` failed)'
    return ', '.join(sessions)


def _banner(lines: List[str]) -> str:
    bar = '!' * 72
    return '\n'.join([bar, *(f'!! {line}' for line in lines), bar])


def hold_message(p: Dict[str, Any]) -> str:
    lines = [
        f"HERDR HELD BACK: {p['herdr_installed']} -> {p['herdr_candidate']} NOT upgraded.",
        f"Live herdr session(s): {_sessions_label(p['live_sessions'])}.",
        'A herdr upgrade can bump the client/server protocol. The running server',
        'then rejects every call until `herdr server stop`, which closes ALL panes.',
        f'Upgrade it deliberately, from a terminal tab OUTSIDE herdr:  {DELIBERATE_PATH}',
    ]
    return _banner(lines)


def skew_message(p: Dict[str, Any]) -> str:
    return _banner([
        f"HERDR PROTOCOL SKEW: session(s) {', '.join(p['skewed_sessions'])} run a server",
        'that is not compatible with the installed client, so herdr calls fail.',
        f'Restart deliberately, from a terminal tab OUTSIDE herdr:  {DELIBERATE_PATH}',
    ])


def cmd_brew_upgrade(extra_env: Optional[Dict[str, str]] = None) -> int:
    p = plan()
    env = dict(os.environ, **(extra_env or {}))

    if p['action'] == 'upgrade-all':
        os.execvpe('brew', ['brew', 'upgrade'], env)

    if p['action'] == 'error':
        print(_banner([
            f"herdr session(s) may be live ({_sessions_label(p['live_sessions'])}),",
            'and `brew outdated --json=v2` failed, so herdr cannot be safely excluded.',
            'Not running `brew upgrade`. Fix brew, or upgrade herdr deliberately:',
            f'  {DELIBERATE_PATH}',
        ]), file=sys.stderr)
        return 1

    if p['skewed_sessions']:
        print(skew_message(p), file=sys.stderr)
    if p['herdr_candidate']:
        print(hold_message(p), file=sys.stderr)
    else:
        print(f"herdr: up to date; live session(s): {_sessions_label(p['live_sessions'])}. "
              'Upgrading explicit targets so an auto-update cannot slip herdr in.',
              file=sys.stderr)

    if not p['targets']:
        print('brew: nothing else to upgrade.', file=sys.stderr)
        return 0
    # Explicit names never pick up herdr; skip the auto-update so the target
    # list we just computed is the one brew acts on.
    env['HOMEBREW_NO_AUTO_UPDATE'] = '1'
    os.execvpe('brew', ['brew', 'upgrade', *p['targets']], env)


def cmd_status() -> int:
    p = plan()
    if p['action'] == 'upgrade-all':
        print('live sessions: none')
        print('herdr: no live server; the routine `just upgrade` upgrades herdr normally.')
        return 0
    print(f"live sessions: {_sessions_label(p['live_sessions'])}")
    if p['action'] == 'error':
        print('herdr: cannot tell whether herdr is outdated (`brew outdated` failed).')
        return 1
    if p['skewed_sessions']:
        print(f"protocol skew: {', '.join(p['skewed_sessions'])}")
    if p['herdr_candidate']:
        print(f"herdr: {p['herdr_installed']} -> {p['herdr_candidate']} available; "
              f'held back by `just upgrade`; run `{DELIBERATE_PATH}`.')
    else:
        print('herdr: up to date.')
    return 0


def cmd_live_sessions() -> int:
    sessions = live_sessions()
    if sessions is None:
        print('herdr session list failed', file=sys.stderr)
        return 1
    for name in sessions:
        print(name)
    return 0


def main(argv: List[str]) -> int:
    commands = {
        'brew-upgrade': cmd_brew_upgrade,
        'status': cmd_status,
        'live-sessions': cmd_live_sessions,
    }
    if len(argv) != 1 or argv[0] not in commands:
        print(f"usage: herdr_guard.py {{{'|'.join(commands)}}}", file=sys.stderr)
        return 2
    return commands[argv[0]]()


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
