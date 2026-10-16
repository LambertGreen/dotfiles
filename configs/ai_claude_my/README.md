# ai_claude_my: `~/.claude` as one folder link (personal)

On personal machines, `~/.claude` is a single stow **folder link** to `dot-claude/`. That
directory is a **private submodule**,
[`dot-claude-my`](https://github.com/LambertGreen/dot-claude-my). Its twin is `ai_claude_work`
(`dot-claude-work`). Each Mac class stows exactly one of the two, the same way
`git_my`/`git_work` split.

| Class | Package | `~/.claude` → |
|-------|---------|---------------|
| `laptop_personal_mac` | `ai_claude_my` | `configs/ai_claude_my/dot-claude` |
| `laptop_work_mac` | `ai_claude_work` | `configs/ai_claude_work/dot-claude` |
| every other class | `ai_claude` (per-file `~/.claude/CLAUDE.md` link only) | real directory |

## Why a folder link (B25)

AI tools and corp apps (DevBar, AI Suite, Claude Code itself) rewrite files in
`~/.claude` by writing a temp file and renaming it over the original, or by
copy/paste. Either one replaces a per-file stow symlink with a plain file. On 2026-10-09
the work Mac's freshly stowed `settings.json` was a plain file again two minutes later,
and nothing reported it.

Inside a linked folder, the same rename lands in this tree. So every rewrite, from any
app, shows up as uncommitted changes in the submodule and as a `⚠` from
`just doctor-check-claude-settings` (which `just sync` in the Council reports).

This follows the repo's precedent for large config folders: `~/.emacs.d`, `~/.config/nvim`
and `~/.hammerspoon` are folder links into submodules whose own `.gitignore` hides runtime
state. Like `sshconfig`, the submodule is **private**, because `~/.claude` sits next to
transcripts, memory and credentials.

## The safety boundary: two allow-lists

Everything Claude Code writes to `~/.claude` (sessions, transcripts, project memory,
plugins, caches, and on Linux `.credentials.json`) physically lives in
`dot-claude/`. Two allow-lists keep it out of git and out of stow:

1. **`dot-claude/.gitignore`** (in the submodule): `/*`, then `!/` lines for the curated
   files only (`.gitignore`, `README.md`, `CLAUDE.md`, `settings.json`). A name nobody has
   seen before stays ignored. The doctor check lists unknown top-level names with `ℹ`, so a
   new writer is still noticed.
2. **`.stow-local-ignore`** (here): stow folds `~/.claude` into one link. If `~/.claude` is
   a real directory instead, stow links only `settings.json` and `CLAUDE.md`, never
   runtime entries.

`tests/test_claude_dir.py` proves both against a corpus of runtime names seen in a live
`~/.claude`, plus names nobody has seen yet.

**To track a new file** (e.g. `commands/`): add `!/commands/` to `dot-claude/.gitignore`,
add it to the regex in `.stow-local-ignore`, and add it to `CURATED`/`STOWED` in
`tests/test_claude_dir.py`. Review what writes it first.

## Day to day

- A `⚠ ~/.claude has N uncommitted change(s)` warning means something rewrote a curated
  file. Review it with `git -C configs/ai_claude_my/dot-claude diff`, then commit there
  (or `git checkout` to revert). Publish with `just git-push` (submodules first), then
  `just git-bump-pins`.
- Keep `settings.json` portable: no secrets (credentials belong in `apiKeyHelper` or the
  environment), and write `"$HOME/..."` in hook and `statusLine` commands, not absolute
  paths.

## Hazards: live state is inside a git working tree

`dot-claude/` in the **primary checkout** is the live `~/.claude`. A dotfiles worktree has
only the curated files. In the primary, never:

- `git clean -x`/`-X` or `git stash --all` in `dot-claude/` (they delete or stash ignored
  files, i.e. every session, transcript and memory);
- `git submodule deinit -f`, `git rm`, or trash `configs/ai_claude_my` (removes the working
  tree);
- `git add -f` anything under `dot-claude/`.

`just git-sync` is safe: it never passes `--force`, and checkout leaves ignored files
alone.

## Migration: real directory → folder link

`scripts/claude/migrate-dir.sh` does it, and `--rollback` undoes it. Every entry is `mv`'d
(a rename on the same volume, so inodes and mtimes are kept); nothing is copied or
dropped except the two old per-file links. A `ditto` backup is taken first anyway. The
script refuses to change anything if an entry would be committable, already exists in
the repo, or the submodule is dirty. After moving, it checks `git status` and rolls back on
its own if anything other than a curated edit shows.

Order: personal Mac first (rehearsed against a copy on 2026-10-16), then the work Mac.

1. On the Mac: `just git-sync`. This pulls master with this change and initializes the
   submodule. Until migration, the old per-file links keep working: `settings.json`
   keeps its path inside the submodule, and the `ai_claude` `CLAUDE.md` link is left
   alone.
2. Preview, read-only, safe with Claude running:

   ```bash
   bash scripts/claude/migrate-dir.sh --dry-run
   ```

   It must end with `✅ Dry run: the migration would proceed.` On the work Mac, expect
   `adopt: settings.json` if the live file drifted. That is fine: it becomes a diff to review.
3. **Quit every Claude session on this machine**, the Council and missions included
   (`pgrep -x claude` must print nothing). Then, from a plain terminal (the Council
   stages it with `attune`):

   ```bash
   bash ~/dev/my/dotfiles/scripts/claude/migrate-dir.sh
   ```

4. Check:
   - `just doctor-check-claude-settings` prints `✓ ~/.claude → ai_claude_my (folder link)`.
   - `just stow-check` exits 0.
   - Start Claude: `/memory` shows the project memory, and `claude --resume` lists past
     sessions.
5. After a few days with no problems, `trash ~/.claude.pre-dirstow-*`.

**Rollback**, again with no Claude session running:

```bash
bash ~/dev/my/dotfiles/scripts/claude/migrate-dir.sh --rollback
```

That unstows the link, moves every runtime entry back into a real `~/.claude`, and
re-links `settings.json` and `CLAUDE.md` per file. Last resort, the backup:
`trash ~/.claude && ditto ~/.claude.pre-dirstow-<stamp> ~/.claude`.

## Why only the two Macs

Other personal classes (`desktop_home_ubuntu`, `vm_personal_ubuntu_arm64`,
`desktop_gaming_win`, `vm_dev_windows_arm64`, the `docker_*` images) keep the per-file
`ai_claude` `CLAUDE.md` link. Their live `settings.json` files were never reviewed, and
`settings.json` carries a SessionStart hook for herdr, which only the Macs install.
Adding a class means adding its package to its `stow.txt`, then migrating as above.
