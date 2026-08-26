#!/usr/bin/env bash
#
# Advance submodules PAST their pins to the tip of their tracked branch (the
# PRODUCER direction) -> just git-update-submodules
#
# Use this when you want to pick up new upstream work and re-pin it. The
# counterpart is scripts/git/sync.sh, which moves the other way (working trees
# TO the pins) and never touches a pin.
#
# WHY NOT `git submodule update --remote --merge`
# -----------------------------------------------
# That one-liner was the previous implementation and had two problems:
#
#   1. It creates a MERGE COMMIT inside the submodule if the local branch has
#      diverged from the remote. A stray merge commit in a config repo is
#      confusing and easy to push by accident. --ff-only refuses instead.
#   2. It fails opaquely when .gitmodules declares a branch that does not exist
#      on the remote. dot-spacemacs.d declared `branch = master` while the repo
#      only has `main`, so this recipe was broken for that submodule and the
#      error told you nothing useful.
#
# Doing it per-submodule costs a few lines and gives an actionable message.

set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "$DOTFILES_DIR"

# shellcheck source=scripts/git/common.sh
source "$DOTFILES_DIR/scripts/git/common.sh"

# Pre-flight: the fetches below are all git-over-ssh, so the config must be
# readable by ssh before we start, not merely repaired afterwards.
bash "$DOTFILES_DIR/scripts/ssh/fix-perms.sh" --quiet

echo "🔄 Advancing submodules to the tip of their tracked branch..."
git submodule sync --recursive --quiet
git submodule update --init --recursive --quiet

moved=0
problems=0

while IFS=$'\t' read -r pin spath; do
    [ -d "$spath/.git" ] || [ -f "$spath/.git" ] || continue

    branch=$(dotfiles_submodule_branch "$spath")
    if [ -z "$branch" ]; then
        # Vendored upstream (spacemacs, doomemacs). Deliberately pinned; we do
        # not chase their upstream on a whim.
        continue
    fi

    git -C "$spath" fetch --quiet origin 2>/dev/null || true

    if ! git -C "$spath" show-ref --verify --quiet "refs/remotes/origin/$branch"; then
        echo "   ❌ $spath"
        echo "      .gitmodules declares branch '$branch', but origin/$branch does not exist."
        echo "      Fix the declaration:  git config -f .gitmodules submodule.<name>.branch <real-branch>"
        problems=1
        continue
    fi

    tip=$(git -C "$spath" rev-parse "refs/remotes/origin/$branch")
    if [ "$tip" = "$pin" ]; then
        continue
    fi

    # --ff-only: refuse rather than invent a merge commit inside a config repo.
    if ! git -C "$spath" checkout --quiet "$branch" 2>/dev/null; then
        git -C "$spath" checkout --quiet -b "$branch" "$tip"
    fi
    if ! git -C "$spath" merge --ff-only "$tip" --quiet 2>/dev/null; then
        echo "   ⚠ $spath: local $branch has diverged from origin/$branch — skipped."
        echo "      Resolve by hand, then re-run."
        problems=1
        continue
    fi

    printf '   %-52s %s → %s\n' "$spath" "${pin:0:7}" "${tip:0:7}"
    moved=1
done < <(dotfiles_submodules)

if [ "$moved" -eq 0 ] && [ "$problems" -eq 0 ]; then
    echo "   ✓ All submodules already at their branch tips"
elif [ "$moved" -eq 0 ]; then
    echo "   No pins moved (see the problems above)."
else
    echo ""
    echo "📌 Pins have moved. Review, then commit the bump in the parent repo:"
    echo "     git add -- <submodule paths> && git commit -m 'chore: bump submodule pins'"
    echo "   Or see everything at once:  just git-status"
fi

# Any checkout can have rewritten the ssh config under the umask.
echo ""
bash "$DOTFILES_DIR/scripts/ssh/fix-perms.sh"

exit "$problems"
