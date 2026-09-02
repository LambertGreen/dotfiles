# Shell config design — the landing pad and the safe file

## The problem this solves

Tool installers (aisuite, devbar, conda, rustup, …) auto-append `export` lines to
`~/.zshrc`, `~/.bashrc`, and `~/.bash_profile`. They write **absolute paths for
the machine they ran on**, they do not ask, and they rewrite their own blocks in
place between sentinel markers (`# >>> aisuite >>>` … `# <<< aisuite <<<`,
`# devbar-managed-start` … `# devbar-managed-end`).

You cannot stop them and you cannot negotiate with them. The design has to
assume they will clobber whatever is at that path.

## The split

| File | Tracked? | Role |
| --- | --- | --- |
| `~/.zshrc` (`configs/shell_common/dot-zshrc`) | yes — see defect below | **Landing pad.** Thin, sacrificial. The installers' target. ~46 lines, almost all comments. |
| `~/.zshrc.user` (`configs/shell_common/dot-zshrc.user`) | yes | **The big common file.** ~860 lines. All real configuration. Safe because no installer knows this path exists. |

Same shape for `.bashrc` and `.bash_profile`.

**The rule: put configuration in `.user`. Never in the pad.** The pad's job is to
source `.user` first (so our config has precedence) and then absorb whatever the
installers write below the injection marker.

## There is no `~/.zshrc.local`

The pads used to source `~/.zshrc.local`, commented "machine-specific, gitignored
if exists." That was a **false promise** and has been removed:

- No installer writes there — they only ever target `~/.zshrc`. So nothing
  populates it.
- No `.gitignore` rule ever existed for it.
- On at least one machine the file had never been created at all.

It made the split look like it had a machine-local escape hatch when it had
none, which is worse than not offering one. If you need a genuine machine-local
override today, put it in `.user` behind a `[[ -d … ]]` / hostname guard.

## Known defect: the pads are tracked and stowed

`~/.zshrc` is a stow symlink into this repo, so **installers write through the
symlink straight into git**, and their machine-specific absolute paths then
travel to every other machine on the next pull.

This is how `/Users/lambert.green/.aisuite/...` ended up live in `PATH` on the
personal Mac, and why `NODE_EXTRA_CA_CERTS` pointed at a nonexistent cert file
there — producing a warning on every single `npm` invocation.

**Interim rule, enforced by hand:** every block in the injection zone must be
`$HOME`-relative and wrapped in a `[[ -d … ]]` guard so it goes inert on
machines where the tool is not installed. The hand-written DevBar block always
did this correctly; the auto-injected blocks did not, and have been corrected.
Expect an installer to revert its own block the next time it runs — on the
machine where that tool is actually installed.

**The real fix (not yet done)** is to stop *tracking* the pads. They stay stow
symlinks — that does not change. Stow links whatever sits in the package
directory and does not care whether git tracks it (verified: stow links a
gitignored file without complaint). Untracking is enough, because installer
output then lands in a file that never gets committed and so never propagates.

1. Add tracked templates outside the stow tree (e.g. `templates/shell/zshrc.pad`)
   so they are never linked into `$HOME`.
2. Add an idempotent `just shell-init-pads` recipe: for each pad, if the file is
   missing, create it from its template. Doubles as fresh-machine bootstrap.
3. `git rm --cached` the three pads and add them to `.gitignore`.
4. On **each** machine: `git pull`, then `just shell-init-pads`.

`scripts/stow/stow.sh`'s pre-stow backup loop needs **no change**. It only moves
aside `~/.zshrc` when that path is a *real file* rather than a symlink, and under
this design it stays a symlink.

### What step 4 costs, measured

Pulling the untracking commit deletes the pad from the working tree, so
`~/.zshrc` dangles until `shell-init-pads` runs. Measured behavior:

| Situation on the receiving machine | What happens |
| --- | --- |
| Working tree clean | Pull **deletes** the pad. `~/.zshrc` dangles. |
| Pad has uncommitted local edits | Git **refuses the pull** ("Please commit your changes or stash them"). Pad survives, pull is blocked. |
| `~/.zshrc` dangling | zsh starts normally and silently skips the missing rc. |

So the window is an *unconfigured* shell, not a broken one — new shells come up
bare until the recipe runs. Recoverable, but do steps 1–2 first and land them
everywhere before step 3, so the recipe already exists when the pad disappears.
