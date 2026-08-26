#!/usr/bin/env bash
#
# Publish local work: submodules first, then the parent repo
# -> just git-push
#
# ORDER IS THE WHOLE POINT
# ------------------------
# Submodules are pushed BEFORE the parent. A parent commit records submodule
# pins by sha; if the parent lands on the remote while a pinned submodule
# commit is still local-only, every other machine gets a repo it cannot
# populate ("direct fetch of that commit failed"). Pushing children first means
# the pin is always fetchable by the time anything references it.
#
# This is the counterpart to just git-bump-pins, which refuses to CREATE such a
# pin in the first place. Together they close the loop that caused the 2026-08
# ssh config drift: work committed inside a submodule, never published, and the
# parent pin left pointing somewhere only one machine could see.

set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "$DOTFILES_DIR"

# shellcheck source=scripts/git/common.sh
source "$DOTFILES_DIR/scripts/git/common.sh"

# Every remote here is git-over-ssh; assert the config is readable first.
bash "$DOTFILES_DIR/scripts/ssh/fix-perms.sh" --quiet

pushed=0
problems=0
unbumped=0

# ─────────────────────────────────────────────────────────────────────────────
# 1. Submodules
# ─────────────────────────────────────────────────────────────────────────────
echo "⬆️  Publishing submodule work..."

while IFS=$'\t' read -r pin spath; do
    [ -e "$spath/.git" ] || continue

    head=$(git -C "$spath" rev-parse HEAD)
    branch=$(dotfiles_submodule_branch "$spath")

    # Track whether the parent still needs a pin bump for this one.
    if [ "$head" != "$pin" ] && ! git -C "$spath" merge-base --is-ancestor "$head" "$pin" 2>/dev/null; then
        unbumped=1
    fi

    if [ -z "$branch" ]; then
        continue    # vendored upstream; we never push to those
    fi

    if ! git -C "$spath" show-ref --verify --quiet "refs/remotes/origin/$branch"; then
        echo "   ⚠ $spath: origin/$branch does not exist — skipped"
        problems=1
        continue
    fi

    # Anything here that origin/<branch> does not already have?
    n=$(git -C "$spath" rev-list --count "refs/remotes/origin/$branch..HEAD" 2>/dev/null || echo 0)
    if [ "$n" = "0" ]; then
        continue
    fi

    current=$(dotfiles_current_branch "$spath")
    if [ "$current" = "(detached)" ]; then
        # Commits made on a detached HEAD. Pushing them would need an explicit
        # refspec, and guessing the user's intent here is exactly the wrong
        # move - show the recovery instead of improvising one.
        echo "   ⚠ $spath: $n commit(s) stranded on a DETACHED HEAD."
        echo "     They are on no branch, so they cannot be pushed as-is. Recover with:"
        echo "       cd \"$spath\""
        echo "       git branch -f $branch $head && git checkout $branch && git push origin $branch"
        problems=1
        continue
    fi

    echo "   ↑ $spath: pushing $n commit(s) to origin/$branch"
    if git -C "$spath" push --quiet origin "$current"; then
        pushed=1
    else
        echo "     ❌ push failed"
        problems=1
    fi
done < <(dotfiles_submodules)

if [ "$pushed" -eq 0 ] && [ "$problems" -eq 0 ]; then
    echo "   ✓ No unpublished submodule commits"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 2. Parent repo
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "⬆️  Publishing the dotfiles repo..."

if [ "$unbumped" -eq 1 ]; then
    echo "   ⚠ Some submodules are ahead of their pins — those changes will NOT"
    echo "     propagate until the pins are recorded:  just git-bump-pins"
fi

if upstream=$(git rev-parse --abbrev-ref '@{u}' 2>/dev/null); then
    ahead=$(git rev-list --count "$upstream..HEAD")
    if [ "$ahead" = "0" ]; then
        echo "   ✓ Nothing to push"
    else
        echo "   ↑ pushing $ahead commit(s) to $upstream"
        git push --quiet origin HEAD
        echo "   ✓ $(git rev-parse --short HEAD) published"
    fi
else
    echo "   ⚠ No upstream configured for this branch; not pushing"
    problems=1
fi

exit "$problems"
