# ai_claude_my — Claude Code `settings.json` (personal)

Stows `~/.claude/settings.json` on personal machines. Its twin is
`ai_claude_work`; each machine class stows exactly one, the same way
`git_my`/`git_work` and `finicky_my`/`finicky_work` split.

| Class | Package |
|-------|---------|
| `laptop_personal_mac` | `ai_claude_my` |
| `laptop_work_mac` | `ai_claude_work` |
| every other class | none (see below) |

Shared, non-settings files (`CLAUDE.md`) stay in `ai_claude`. The MCP
`dot-claude.json.template` stays in the OS packages (`ai_claude_osx`/`_linux`/`_win`).

## Claude Code writes to this file — on purpose

Claude Code rewrites `settings.json` itself: `/config`, plugin enables, and
`autoMode` edits. Through the stow symlink those writes land in this repo.
That is the point: drift shows up as `git diff`, and gets reviewed and
committed (or reverted) like any other change.

Keep it portable when you commit:

- No secrets. Credentials belong in `apiKeyHelper` or the environment, never here.
- No absolute home paths. Hook and `statusLine` commands run through a shell,
  so write `"$HOME/..."`; in `autoMode` prose write `~/...`.

## Adopting a live file (first switch on a machine)

Stow refuses to replace a plain file, and `just stow` would back it up and
replace it with the repo copy, so adopt deliberately:

1. Copy the live file over `configs/ai_claude_my/dot-claude/settings.json`,
   then `git diff` it. Re-apply the portability rules above.
2. Commit.
3. Back up, trash and stow (run from anywhere, after the commit is on the
   checkout at `~/dev/my/dotfiles`):

   ```bash
   cp -p ~/.claude/settings.json ~/.claude/settings.json.pre-stow && trash ~/.claude/settings.json && stow --dir="$HOME/dev/my/dotfiles/configs" --target="$HOME" --dotfiles --no-folding --ignore='\.stowrc' ai_claude_my && readlink ~/.claude/settings.json && jq . ~/.claude/settings.json
   ```

4. `just doctor-check-claude-settings` should print `✓`.

## Why only one class

`laptop_personal_mac` was seeded from its live file on 2026-10-08. Other
personal classes (`desktop_home_ubuntu`, `vm_personal_ubuntu_arm64`,
`desktop_gaming_win`, `vm_dev_windows_arm64`, the `docker_*` test images) are
left out deliberately: the file carries a SessionStart hook for herdr, which
only the Macs install, and their live files have never been reviewed. Add a
class here only after adopting its live file with the steps above.
