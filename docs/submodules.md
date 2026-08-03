# Managing Git Submodules

This repo uses git submodules for configs that are either private (e.g. the SSH
config at `configs/ssh_common/dot-ssh` → private `sshconfig` repo) or maintained
as their own repos (Emacs, nvim, hammerspoon, etc.). See `.gitmodules` for the
full list; most declare a tracked `branch`.

## The detached-HEAD gotcha (why this doc exists)

`git submodule update` checks out each submodule at its **pinned commit as a
detached HEAD**. That is the *normal, correct* state — don't be alarmed by it.

The trap: if you `cd` into a submodule and **commit while on that detached
HEAD**, the commit is stranded off any branch, and the submodule's working tree
silently diverges from what the parent repo pins. On 2026-08 this broke the SSH
config — a personal-GitHub push failed because `~/.ssh/config` was a stale
detached checkout of a superseded commit, not the branch tip.

## Rules

1. **Before editing a submodule**, get onto its branch:
   ```bash
   cd <submodule>
   git checkout <branch>   # the branch from .gitmodules, e.g. main
   ```
2. **After committing/pushing in a submodule**, re-pin it in the parent:
   ```bash
   cd <repo root>
   git add <submodule path>
   git commit -m "chore: bump <submodule> pin"
   ```
   Without this, the change won't propagate on other machines' `git submodule
   update`.
3. **Never** commit on a detached HEAD inside a submodule.

## Recipes

| Command | What it does |
|---------|--------------|
| `just sync-submodules` | Clone/init submodules at their pinned commits (setup flow). Leaves them detached-at-pin — correct. |
| `just update-submodules` | Advance each submodule to the latest commit on its tracked branch (`--remote --merge`), landing on the branch (not detached). Then shows which pins moved so you can commit the bump. |
| `just doctor-check-submodules` | Report genuine drift only: checked-out commit ≠ pin (`+`), conflicts (`U`), or uninitialized (`-`). Does **not** flag normal detached-HEAD-at-pin. |

## Recovering from drift

If `just doctor-check-submodules` reports a submodule's commit differs from the
pin (`+`):
- **Keep the local changes:** get on the branch, push, then re-pin in the parent
  (rules 1–2 above).
- **Discard the local changes:** `git submodule update --recursive` resets the
  submodule back to the parent's pinned commit.

## Related

- SSH key/config policy and per-machine audit: private `sshconfig` submodule
  (`README.md`, `AUDIT.md`, `SETUP.md` inside `configs/ssh_common/dot-ssh`).
- GPG policy: `configs/gnupg_common/README.md`.
