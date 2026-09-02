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

**The real fix (not yet done)** is to stop tracking the pads, so installer
output lands in an untracked file and never propagates:

1. Add a template (e.g. `configs/shell_common/templates/zshrc.landing-pad`),
   *not* stowed.
2. Add a recipe that materializes `~/.zshrc` as a **real file** from that
   template, preserving any existing injection blocks.
3. Add the pads to `configs/shell_common/.stow-local-ignore`.
4. **Patch `scripts/stow/stow.sh`** — its `shell_common` pre-stow loop moves any
   *real* (non-symlink) `~/.zshrc` aside to `.backup-<date>`. With the pad
   stow-ignored, that loop would rename the machine's real pad away and leave
   nothing in its place. It must skip the pads.
5. Only then `git rm --cached` the pads.

**Sequencing matters.** Steps 1–2 must land and be run on *every* machine before
step 5, because once the tracked pad is deleted, the next `git pull` on a
machine that still has a symlinked `~/.zshrc` leaves that symlink dangling — a
broken login shell.
