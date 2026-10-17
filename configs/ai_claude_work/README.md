# ai_claude_work: `~/.claude` as one folder link (work)

On `laptop_work_mac`, `~/.claude` is a single stow **folder link** to `dot-claude/`, which is
the **private submodule** [`dot-claude-work`](https://github.com/LambertGreen/dot-claude-work).
Its twin is `ai_claude_my`. **The design, the two allow-lists, the hazards and the
migration/rollback runbook are in [`../ai_claude_my/README.md`](../ai_claude_my/README.md).**
Everything there applies here with `ai_claude_my` → `ai_claude_work`.

The work Mac is where B25 bit: on 2026-10-09 its stowed `settings.json` turned back into a
plain file within two minutes. The lead suspects are DevBar and AI Suite, which rewrite
user dotfiles on their own schedule. After migration, that rewrite shows up as
`⚠ ~/.claude has N uncommitted change(s)` instead of a silently broken link.

## What `settings.json` carries

The DevBar `apiKeyHelper`, the model gateway env, telemetry hooks, and the AI Suite /
salesforce plugin marketplaces. Until 2026-10-16 this file was in the **public** dotfiles
tree (history keeps those copies); it now lives only in the private submodule.

- `autoMode.allow` holds the work publishing rule. Claude may push its own non-default
  branch and run `gh pr create --draft|edit|comment` on the `sf-analyticscloud` and
  `sf-analyticscloud-sandbox` orgs, and `gh pr ready` only on Lambert's say-so. AI Council
  work missions need it (`ai_council` `docs/protocols/mission-bootstrap.md`, "Work-machine
  prerequisite"). It mirrors the `LambertGreen/*` rule in `ai_claude_my`.
- The last `SessionStart` group is herdr's session-id hook. herdr only knows a pane's Claude
  session id if this hook reports it (`herdr agent list` → `agent_session`), and the
  Council's recovery keys on that. `herdr integration install claude` writes it with an
  absolute path; it's kept here in `$HOME` form. `hooks/herdr-agent-state.sh` itself is
  herdr's, so it stays untracked.

## Migrating the work Mac

Follow the runbook in `../ai_claude_my/README.md`, after the personal Mac has held. Work
specifics:

- The live `settings.json` has likely drifted from the seed (the 2026-10-09 copy). The dry
  run shows `adopt: settings.json`, and after migration it is a diff in the submodule.
  Review it before committing: no secrets (the token comes from `apiKeyHelper`), and
  `$HOME/` instead of `/Users/<you>/` in hook and `statusLine` commands.
  `NODE_EXTRA_CA_CERTS` and the `aisuite` marketplace `path` are not shell-expanded, so
  they stay absolute.
- `statusline.sh` (referenced by `statusLine`) and AI Suite's files stay machine-local
  (ignored). To track `statusline.sh`, follow "To track a new file".
- Keep `cortana_common` stowed here until this Mac's `~/dev/my/ai` clone is retired (see
  the TODO in `machine-classes/laptop_work_mac/stow/stow.txt`).

## Not on work Linux/Windows

`desktop_work_ubuntu`, `wsl_work_ubuntu`, `desktop_work_win` and
`server_dev_win_hammerhead` keep the per-file `ai_claude` `CLAUDE.md` link: this
`settings.json` is macOS-only (`/Applications/devbar.app`, `/Users/...` paths).
