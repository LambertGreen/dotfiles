# ai_claude_work — Claude Code `settings.json` (work)

Stows `~/.claude/settings.json` on `laptop_work_mac`: the devbar
`apiKeyHelper`, the model gateway env, telemetry hooks, and the AI Suite /
salesforce plugin marketplaces. Its twin is `ai_claude_my`; see that README
for the class table and for why Claude Code writing to this file through the
symlink is intended (drift shows up as `git diff`).

Moved here from `ai_claude_osx` on 2026-10-08. That copy was last updated
2026-07-21, and the live work file has drifted past it since.

## Adopt the live work file — do this BEFORE the next `just stow`

The work Mac was seen with a plain `~/.claude/settings.json`. `just stow`
would back that file up and replace it with the stale copy here, so adopt
first:

1. Take the live file into the repo:

   ```bash
   cp ~/.claude/settings.json ~/dev/my/dotfiles/configs/ai_claude_work/dot-claude/settings.json
   ```

2. Review: `git -C ~/dev/my/dotfiles diff configs/ai_claude_work`. Check for
   - secrets: none may be committed (the token comes from `apiKeyHelper`);
   - absolute home paths: hook and `statusLine` commands run through a shell,
     so rewrite `/Users/<you>/` to `$HOME/` there. `NODE_EXTRA_CA_CERTS` and
     the `aisuite` marketplace `path` are not shell-expanded; leave them
     absolute until Claude Code is confirmed to expand `~` in them.
3. Commit on a branch and open a PR.
4. Back up, trash and stow:

   ```bash
   cp -p ~/.claude/settings.json ~/.claude/settings.json.pre-stow && trash ~/.claude/settings.json && stow --dir="$HOME/dev/my/dotfiles/configs" --target="$HOME" --dotfiles --no-folding --ignore='\.stowrc' ai_claude_work && readlink ~/.claude/settings.json && jq . ~/.claude/settings.json
   ```

5. `just doctor-check-claude-settings` should print `✓`.

## Not stowed on work Linux/Windows

`desktop_work_ubuntu`, `wsl_work_ubuntu`, `desktop_work_win` and
`server_dev_win_hammerhead` are left out deliberately: the file is
macOS-only (`/Applications/devbar.app`, `/Users/...` paths).
