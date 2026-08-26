# Managing Git Submodules

This repo uses git submodules for configs that are either private (e.g. the SSH
config at `configs/ssh_common/dot-ssh` → private `sshconfig` repo) or maintained
as their own repos (Emacs, nvim, hammerspoon, etc.). See `.gitmodules` for the
full list; most declare a tracked `branch`.

## The one idea that matters: consumer vs producer

Submodule work runs in two directions. Conflating them is how machines drift
apart, so every `just git-*` recipe picks a side and stays on it:

| | **Consumer** | **Producer** |
|---|---|---|
| What is the truth? | The **pins** in the parent repo | The **remote branch** |
| Moves working trees | *to* the pins | *past* the pins |
| Moves pins? | **Never** | Yes — you commit the bump |
| When | Sitting down at a machine | Deliberately publishing or adopting work |
| Commands | `git-sync`, `git-sync-submodules` | `git-push`, `git-bump-pins`, `git-update-submodules` |

`git-sync` is the one you want almost always. If you just pulled and something
looks stale, you wanted `git-sync`.

## Recipes

| Command | What it does |
|---------|--------------|
| `just git-sync` | **The daily driver.** Fast-forwards the parent repo, lands every submodule on its pin, re-asserts SSH permissions, and tells you what moved and what needs a reload. |
| `just git-sync-submodules` | Submodules only; leaves the parent repo alone. Also the setup-flow step (aliased as `sync-submodules`). |
| `just git-update-submodules` | Producer direction: advance each submodule to its branch tip so you can commit new pins (aliased as `update-submodules`). |
| `just git-bump-pins` | Record moved submodules as new pins. **Refuses** to pin an unpublished commit. Takes `--yes` to skip the prompt. |
| `just git-push` | Publish local work: submodules first, then the parent. |
| `just git-status` | Parent repo + every submodule on one screen: drift from pins, detached HEADs, unpushed commits. |
| `just doctor-check-submodules` | Reports drift and invalid `.gitmodules` branch declarations. |
| `just doctor-fix-ssh-perms` | Re-asserts SSH file modes on demand. |

## Publishing work you did inside a submodule

```bash
cd configs/ssh_common/dot-ssh
# ...edit, then commit as normal (git-sync already put you on the branch)
cd -
just git-push        # pushes the submodule
just git-bump-pins   # records the new pin in the parent
just git-push        # publishes the parent
```

**Why the pin has to be pushed last.** A pin is just a sha. If the parent
commit lands on the remote while the submodule commit it references is still
local-only, every other machine gets a repo it cannot populate — `git submodule
update` fails with *"direct fetch of that commit failed"*. The repo looks
perfectly healthy on the machine that made it and is broken everywhere else.

Two guards enforce this, so the ordering is not something you have to remember:

- `git-bump-pins` **refuses** to record a pin whose commit is not reachable from
  the submodule's remote branch, and tells you to `just git-push` first.
- `git-push` always pushes submodules *before* the parent.

If you committed on a detached HEAD anyway, `git-push` detects that the commits
are on no branch, declines to guess a refspec, and prints the exact recovery
(`git branch -f <branch> <sha> && git checkout <branch> && git push`).

The old names `sync-submodules` and `update-submodules` still work — they are
`just` aliases, because they are referenced by the bootstrap flow and by
`SETUP.md` inside the `dot-ssh` submodule, which lives in a different repo.

## Why we attach branches instead of leaving detached HEADs

Plain `git submodule update` lands each submodule at its pin as a **detached
HEAD**. That is legitimate git, but in a dotfiles repo you routinely edit inside
submodules, and a commit made on a detached HEAD is stranded off any branch —
the parent then silently diverges from what it pins. That is exactly what broke
the SSH config in 2026-08: `~/.ssh/config` was a stale detached checkout of a
superseded commit, and a personal-GitHub push failed.

So `git-sync` goes one step further than git does: for every submodule that
declares a `branch` in `.gitmodules`, it also **attaches that branch at the
pin**, leaving you on a branch and safe to edit.

Two cases where it deliberately leaves you detached, because attaching would be
a lie:

- **No declared branch** — vendored upstreams (spacemacs, doomemacs). Detached
  at pin is correct for these.
- **The branch is *ahead* of the pin** — you cannot be on the branch *and* at
  the pin. The pin is what the parent says this machine should have, so it wins.
  `git-status` shows this as *"pinned behind `<branch>` on purpose"*.

## The SSH permissions trap

**Symptom:** every ssh and git-over-ssh command suddenly fails with
`Bad owner or permissions on ~/.ssh/config`.

**Cause:** git writes checked-out files using the process umask. The umask here
is `002`, so git writes mode `664`, and SSH hard-refuses a group-writable
config. Git only tracks the executable bit, so it cannot carry mode `600`
itself — the mode has to be re-asserted by whatever laid the file down.

Any checkout that touches the `dot-ssh` submodule re-breaks this. That is why
`scripts/ssh/fix-perms.sh` is the single source of truth and every relevant path
calls it — `stow`, `git-sync`, `git-sync-submodules`, `git-update-submodules`.

**Note the ordering:** the git recipes fix permissions *before* they fetch, not
only afterwards. All the remotes are git-over-ssh, so a broken mask would
otherwise deadlock the very command that repairs it — the pull fails, so the
repair at the end is never reached.

Fix it by hand any time with `just doctor-fix-ssh-perms`.

## Rules

1. **Before editing a submodule**, run `just git-sync` — it puts you on the
   tracked branch rather than a detached HEAD.
2. **After committing in a submodule**, run `just git-push` → `just
   git-bump-pins` → `just git-push` (see above). Push **before** committing the
   bump: a pin pointing at an unpushed commit cannot be fetched by any other
   machine. `git-bump-pins` enforces this rather than trusting you to remember.
3. **Never** commit on a detached HEAD inside a submodule.

## Recovering from drift

If `just git-status` or `just doctor-check-submodules` reports that a
submodule's commit differs from the pin:

- **Discard the local state, adopt the pin:** `just git-sync`
- **Keep the local work:** push it from inside the submodule, then re-pin in the
  parent (rule 2 above).

`git-sync` never uses `--force`, so a submodule with uncommitted changes will
*refuse* to be checked out rather than lose your work. Commit, stash, or discard
those changes and re-run.

## Keeping `.gitmodules` honest

A `branch` declaration that does not exist on the remote silently breaks
`git-update-submodules`, and the failure tends to surface months later on a
different machine. `dot-spacemacs.d` declared `branch = master` against a repo
that only has `main`, which went unnoticed until 2026-08.

`just doctor-check-submodules` now validates every declaration against the
actual remote. Note that the recipes enumerate submodules from the **git index**
rather than from `.gitmodules`, so stale entries for removed submodules cannot
resurrect themselves.

## Related

- SSH key/config policy and per-machine audit: private `sshconfig` submodule
  (`README.md`, `AUDIT.md`, `SETUP.md` inside `configs/ssh_common/dot-ssh`).
- GPG policy: `configs/gnupg_common/README.md`.
