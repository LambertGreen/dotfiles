# Retro — add `ai_council` launch command alongside `cortana` (dotfiles half of AI Council cutover)

**Date:** 2026-09-12
**Branch:** `ai-council-launch` (off `master`) — **unpushed, push gated**
**Commit:** `80f0134`
**Mission marker:** AI-COUNCIL-DOTFILES-CUTOVER-MISSION
**Mode:** COEXISTENCE — additive only; `cortana` and its package left fully intact.

## Goal

The Cortana → AI Council rename is done inside `~/dev/my/ai_council` (branch `ai-council`).
This mission delivered the **dotfiles half**: a new `ai_council` launch command that boots the
Council in `~/dev/my/ai_council`, **without** removing the existing `cortana` command (which still
boots Cortana in `~/dev/my/ai`). Decommissioning `cortana` is a later mission — Lambert has pending
work on the `cortana` path and cannot lose it yet.

## What shipped

- New stow package `configs/ai_council_common/dot-local/bin/ai_council` — a copy of the `cortana`
  launcher (mode 775, matching cortana) with:
  - `AI_DIR="$HOME/dev/my/ai_council"` (the critical flip; was `$HOME/dev/my/ai`)
  - `AI_REPO=…/ai_council.git` (was `…/ai.git`)
  - `COUNCIL_WORKSPACE_LABEL="Jedi Council"` (was `CORTANA_WORKSPACE_LABEL="Cortana"`)
  - WezTerm window/tab titles → `"Jedi Council"`
  - all `cortana:` prefixes / Cortana prose → `ai_council:` / the Council
  - function renames `cortana_workspace_id`→`council_workspace_id`,
    `enter_cortana_workspace`→`enter_council_workspace`
- Registered `ai_council_common` in `machine-classes/laptop_work_mac/stow/stow.txt` (right after
  `cortana_common`). **This registration was the actual "re-stow" mechanism for this repo.**

## What did NOT need doing (verified, not assumed)

- **No `n` alias exists anywhere** — not in the dotfiles repo, not in live `~/.zshrc`/`~/.bashrc`/
  `~/.bash_profile`/`~/.config`. The spec and mission brief both assumed it existed. Nothing to
  preserve or drop. (Confirmed with Lambert in-pane before proceeding.)
- **No `/cortana-*` slash-command references** inside the launcher — spec step "update `/cortana-*`
  → `/council-*`" was a no-op for this package. (Those live in the Council repo's `.claude/commands/`,
  already handled by the rename mission.)
- No short alias for `ai_council` — the Council has none by design.

## The one real snag: raw `stow` thrashed — because this repo uses `--dotfiles` mode

I first ran raw `stow -R -d configs -t $HOME ai_council_common` and it silently failed: stow printed
`LINK: dot-local/bin/ai_council …` yet no symlink landed on disk; a later run even claimed
`Skipping … as it already points to …` for a link that did not exist. It also thrashed by trying to
**fold** `~/.local` / `~/.local/bin` into a single directory symlink (because both `cortana_common`
and `ai_council_common` share the `dot-local/bin/` structure), repeatedly UNLINK/MKDIR/revert.

**Root cause (thanks to Lambert's steer): the repo drives stow via `just stow` →
`scripts/stow/stow.sh`, which:**
1. `cd configs` first (so `configs/.stowrc` and the relative `--target=~` resolve), and
2. invokes `stow --restow --dotfiles --target=$HOME <pkg>` — reading the package list from
   `machine-classes/$DOTFILES_MACHINE_CLASS/stow/stow.txt`.

My raw calls **omitted `--dotfiles`**, so stow never translated `dot-local` → `.local`; it was
creating phantom literal `dot-local/…` links relative to `$HOME` that never matched the real
`~/.local/bin`. With the correct flags **from inside `configs/`**, the dry run planned exactly one
clean `LINK: .local/bin/ai_council => …` and the real run created it — no folding drama, cortana
untouched.

**Lesson (catalog-worthy):** in this repo, never `stow` a package by hand with ad-hoc flags. Register
it in the machine-class `stow.txt` and either run `just stow`, or replicate its exact invocation:
`cd configs && stow --restow --dotfiles --target=$HOME <pkg>` (add `--no-folding` only if the package
ships a `.stowrc` that says so). `--dotfiles` is mandatory — the `dot-` prefix convention depends on it.

A stray manual `ln -s` I created mid-debug was removed (via `trash`) before the correct path was run;
final state is 100% stow-managed.

## Verification (local, no boot — no TTY in harness)

- `command -v ai_council` → `~/.local/bin/ai_council` ✓
- `command -v cortana` → `~/.local/bin/cortana` ✓ (coexistence intact)
- `command -v n` → none (expected) ✓
- `grep -n AI_DIR= ~/.local/bin/ai_council` → `$HOME/dev/my/ai_council` ✓
- No leftover bare `dev/my/ai` path; every `dev/my/` occurrence is `ai_council` ✓
- Zero residual `cortana`/`Cortana` strings in the new script ✓
- `ai_council --help` renders correctly and exits 0 without launching herdr/Claude ✓
- Pre-commit hooks (shellcheck, shebang/exec, etc.) all passed on the launcher ✓
- Scoped commit: only the new launcher + the stow.txt line; 4 unrelated dirty files
  (emacs, shell rc ×3) left unstaged/untouched ✓

## Open / deferred

- **Workspace label `"Jedi Council"` is a cosmetic dotfiles choice.** The Council repo's
  `scripts/start-orchestrator.sh` uses `WORKSPACE_LABEL="council"` (lowercase) — a *different* tool
  and invocation path, so no collision with the launcher. If Lambert ever wants the launcher and the
  orchestrator script to share one workspace, that's a one-string alignment later.
- **Herdr / Sentinel plugin re-link is host state** (machine-local, needs an interactive pane) — NOT
  done here. Staged as copy-paste in-pane instructions in the check-in message.
- **Push is gated** — commit sits on `ai-council-launch`, unpushed, awaiting Lambert's explicit go.
- Decommissioning `cortana` (remove symlink/package, drop stow.txt line) is a **later mission**.
