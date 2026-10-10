# LuLu (Objective-See firewall)

Snapshot + restore, never stow. LuLu's data dir (`/Library/Objective-See/LuLu/`)
is root-owned and read by its system extension, so nothing here links or writes
into it.

| File | Tracked? | Written by |
|------|----------|------------|
| `preferences.json` | yes | `just lulu-export` (from `preferences.plist`, minus `installTime`/`alertLast*`) |
| rules snapshot | **no** (public repo) | `just lulu-export` → `$LULU_RULES_SNAPSHOT` |

Rules list every app on the machine and the hosts it may reach, so they never
land in this repo (`.gitignore` blocks `machine-classes/*/lulu/rules*.json` as a
backstop). Default location: `${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/lulu/rules.json`.
Set `LULU_RULES_SNAPSHOT` in `~/.dotfiles.env` to keep it somewhere versioned
(e.g. a private repo checkout).

## Commands

```sh
just lulu-export          # prefs → here, user rules → $LULU_RULES_SNAPSHOT (no root)
just lulu-export --all    # include Apple/baseline/default rules too
just doctor-check-lulu    # live vs snapshot; exit 1 on drift
just lulu-import          # prints the restore steps; changes nothing
```

## Format

The rules snapshot is the same JSON LuLu's own **Rules → Export...** writes
(`{ "<signing id or path>": [ rule, ... ] }`, see `Rule.toJSON` in
objective-see/LuLu), decoded from the binary NSKeyedArchiver `rules.plist`,
with keys and rules sorted for stable diffs.

## Restore

LuLu has no CLI import, so restore goes through its UI:

- **Rules:** menu-bar icon → **Rules → Import...** → pick the snapshot. A
  user-only snapshot (the default) *merges*: LuLu replaces only the user-created
  rules. A `--all` snapshot replaces every rule.
- **Settings:** LuLu has no prefs import. `just lulu-import` lists each toggle
  that differs from `preferences.json`; flip them in **Settings**.
