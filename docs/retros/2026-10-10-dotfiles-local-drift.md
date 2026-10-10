# Retro — dotfiles-local-drift (primary checkout drift: DevBar-rewritten pads, stale emacs submodule)

- **Machine:** work Mac (laptop_work_mac, per `~/.dotfiles.env`)
- **Date:** 2026-10-10
- **Branch:** `feature/dotfiles-local-drift` (off `origin/master` f39559e). Draft PR #30, plus LambertGreen/dot-emacs-default#1.
- **Mission marker:** MISSION-DOTFILES-LOCAL-DRIFT-2026-10-10.

## Kickoff Prompt

> The primary checkout (`master`) was dirty and 2 commits behind `origin/master`, so the Council didn't
> pull. Uncommitted: the `dot-emacs.d` submodule pointer, and about 21 lines in each of `dot-bash_profile`,
> `dot-bashrc`, `dot-zshrc`. Find out what each edit is and where it came from, take each to Lambert as
> keep/discard, move kept edits into the worktree branch, restore the primary only after the commit is
> verified, then `pull --rebase` and confirm `check-origin-sync.sh` prints `OK:`. Don't stow, don't push
> master.

## What the drift was

| Item | Writer (evidence) | Decision |
|---|---|---|
| Pads: guards stripped, absolute paths, aisuite block moved after `devbar-managed` | **DevBar 1.12.1.** Its daemon re-exec'd after auto-updating from 1.12.0 and reconnected at 2026-10-06 21:10:23.8 (`~/.devbar/logs/devbar.3.log`). All three pad mtimes are 21:10:23. DevBar also manages the `aisuite` package (`~/.devbar/pkgs/aisuite`). | D1 keep, guarded |
| Pads: new `mhtc-telemetry` block (opencode-shim prepended to `PATH`) | Added by the same 10-06 rewrite. **Removed mid-mission** by the AI Suite telemetry daemon at 2026-10-10 11:50:36 (`~/.aisuite/logs/telemetry-daemon.err`: "collector: consent changed; reconciled enablement enabled=false"). The shim dir was emptied in the same second. | not adopted: its owner removed it |
| `dot-emacs.d` pointer | **Not a pull.** de2fbda (10-05) bumped the pin to 8ea9f9d, but the primary's submodule checkout was never updated and stayed on 0cb2cf6 (`main`, 1 behind). | synced (ff to 8ea9f9d) |
| `dot-emacs.d` `config/init-editor.el` | Hand edit, mtime 2026-09-10 12:54: `:after emabark` (a typo, so embark-consult's `:config` never ran). | D2 fix typo upstream |

## What changed

| Commit | What |
|---|---|
| `016bb23` | The three pads: the injection zone in DevBar's order (devbar-managed, then aisuite), guarded and `$HOME`-relative. The live shell has run with the aisuite cert winning `NODE_EXTRA_CA_CERTS` since 10-06, so this keeps it. |
| `3e82441` | Bumps `dot-emacs.d` to `a61ce26` (dot-emacs-default#1: `:after embark`). |
| dot-emacs-default `a61ce26` | `embark-consult` `:after embark`. |

In the primary, I saved both diffs to patch files before restoring, then restored the three pads and the submodule's `init-editor.el`, fast-forwarded the submodule's `main` to 8ea9f9d (it stays on a branch, not detached), ran `pull --rebase` (b540531 → f39559e) and got `check-origin-sync` `OK:`.

## Decisions

1. **Mirror the tool's block order, don't restore ours.** The pad doctrine (`docs/SHELL_CONFIG_DESIGN.md`) allows "commit it guarded". Matching DevBar's order makes the next rewrite's diff guards-and-paths only, so a reorder can't hide in it.
2. **Drop the mhtc block.** Its owner uninstalled it. A guard on `~/.mh-telemetry-collector-aisuite` would still pass, because the dir outlives the shim, and that would put a dead entry on `PATH`.
3. **Emacs fix on a branch + draft PR, not pushed to `main`.** Per the mission floor. This PR pins the branch commit, so **merge dot-emacs-default#1 with a merge commit first.** Squash or rebase rewrites `a61ce26` and leaves the pin dangling.

## Retro

- **Went well:** mtime-to-log correlation named both writers in minutes. Re-reading the primary before parity-testing caught the second writer, which had changed the files after my first diff.
- **Interim window:** until #30 merges and the primary pulls, the live pads are master's old order, so the devbar cert wins `NODE_EXTRA_CA_CERTS`. That's how the shell was before 10-06, and DevBar puts its order back on its next restart anyway.
- **Expect recurrence:** DevBar rewrites the pads on daemon restarts. AI Suite's installer converges every ~5 minutes (`installer.log`) but didn't touch the pads in the runs I read.
- **Tests:** zone-only parity (`NODE_EXTRA_CA_CERTS` + `PATH`) against the live rewritten pads under the real `HOME`, plus an inert check under an empty `HOME`: 6/6. I ran it before the restore and again after the rebase, against pads rebuilt from the saved patch. `zsh -n` / `bash -n` clean. `check-parens` clean on the elisp. I didn't run Python tests: there's no venv in the worktree, and the change doesn't touch `src/`.

## Tool usage

| Tool | Uses | Fails | Notes |
|---|---|---|---|
| `gh pr create` | 3 | 1 | EMU active account → "Enterprise Managed User" GraphQL error. Read the tools README + gh.md (no account guidance), took the fix from the 10-09 retro: `env GH_TOKEN="$(gh auth token --user LambertGreen)" gh …`. |
| `sd` (multi-line literal) | 2 | 1 | `sd -s` with an embedded newline silently no-opped (as the brief warns). Redone with Edit. |
| `fd --changed-within/--changed-before` | 3 | 1 | Swapped the bounds once (empty window); `--changed-within` is the lower bound. |
| `rg` on installer logs | ~10 | 0 | Logs mix UTC (`installer.log`) and local (`devbar.log`, `telemetry-daemon.err`) times. |
| `git apply` outside a repo | 1 | 0 | Rebuilt the live pads from the saved patch for the post-rebase parity re-run. |
| `emacs --batch` `check-parens` | 1 | 0 | |
