#!/usr/bin/env bash
#
# One-screen git state for the dotfiles repo and every submodule
# -> just git-status
#
# Replaces the `git submodule foreach 'git status'` incantation, and answers
# the questions that actually matter before you start work on a machine:
#   - is my working tree at the pin, or has it drifted?
#   - am I on a branch, or about to commit onto a detached HEAD? (the 2026-08 bug)
#   - do I have commits here that were never pushed?

set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "$DOTFILES_DIR"

# shellcheck source=scripts/git/common.sh
source "$DOTFILES_DIR/scripts/git/common.sh"

# ── Superproject ─────────────────────────────────────────────────────────────
branch=$(git rev-parse --abbrev-ref HEAD)
echo "📦 dotfiles ($branch)"

if upstream=$(git rev-parse --abbrev-ref '@{u}' 2>/dev/null); then
    counts=$(git rev-list --left-right --count "$upstream...HEAD" 2>/dev/null || echo "0	0")
    behind=$(echo "$counts" | cut -f1)
    ahead=$(echo "$counts" | cut -f2)
    if [ "$behind" = "0" ] && [ "$ahead" = "0" ]; then
        echo "   ✓ in sync with $upstream"
    else
        if [ "$behind" != "0" ]; then
            echo "   ⬇ $behind behind $upstream — run: just git-sync"
        fi
        if [ "$ahead" != "0" ]; then
            echo "   ⬆ $ahead ahead of $upstream — unpushed"
        fi
    fi
else
    echo "   ⚠ no upstream configured"
fi

# Count only real edits, not the submodule-pointer noise that dominates
# `git status` in this repo.
dirty=$(git status --porcelain --ignore-submodules=all | wc -l | tr -d ' ')
if [ "$dirty" != "0" ]; then
    echo "   ● $dirty uncommitted change(s) in the parent repo"
fi

# ── Submodules ───────────────────────────────────────────────────────────────
echo ""
echo "🔗 Submodules"

drift=0
detached=0
unpushed=0

while IFS=$'\t' read -r pin spath; do
    if [ ! -e "$spath/.git" ]; then
        printf '   %s %-56s %s\n' "✗" "$spath" "not initialized"
        drift=1
        continue
    fi

    head=$(git -C "$spath" rev-parse HEAD)
    sbranch=$(dotfiles_current_branch "$spath")
    declared=$(dotfiles_submodule_branch "$spath")

    # Position relative to the pin.
    if [ "$head" = "$pin" ]; then
        state="at pin"
        mark="✓"
    elif git -C "$spath" merge-base --is-ancestor "$head" "$pin" 2>/dev/null; then
        n=$(git -C "$spath" rev-list --count "$head..$pin")
        state="$n BEHIND pin — run: just git-sync"
        mark="⬇"
        drift=1
    elif git -C "$spath" merge-base --is-ancestor "$pin" "$head" 2>/dev/null; then
        n=$(git -C "$spath" rev-list --count "$pin..$head")
        state="$n AHEAD of pin — just git-bump-pins"
        mark="⬆"
        drift=1
    else
        state="DIVERGED from pin"
        mark="⚠"
        drift=1
    fi

    # A detached HEAD is only worth flagging when the submodule declares a
    # branch: for vendored upstreams (no declared branch) detached IS correct.
    #
    # And even then there is a benign case: if the declared branch sits AHEAD
    # of the pin, you cannot be on the branch and at the pin simultaneously, so
    # git-sync deliberately leaves it detached. That is the intended outcome,
    # not drift — flagging it would cry wolf on every vendored upstream.
    if [ "$sbranch" = "(detached)" ] && [ -n "$declared" ]; then
        if [ "$head" != "$pin" ]; then
            # Detached AND not at the pin: whatever is here is already off any
            # branch. This is the 2026-08 failure mode, not a benign state --
            # never describe it as intentional.
            state="$state · detached — commits here are STRANDED off-branch"
            mark="⚠"
            detached=1
        elif git -C "$spath" show-ref --verify --quiet "refs/heads/$declared" &&
             git -C "$spath" merge-base --is-ancestor "$pin" "refs/heads/$declared" 2>/dev/null; then
            state="$state · detached, pinned behind $declared on purpose"
        else
            state="$state · detached (edits here would be stranded)"
            mark="⚠"
            detached=1
        fi
    fi

    sdirty=$(git -C "$spath" status --porcelain | wc -l | tr -d ' ')
    if [ "$sdirty" != "0" ]; then
        state="$state · $sdirty local change(s)"
    fi

    if [ -n "$declared" ] && git -C "$spath" show-ref --verify --quiet "refs/remotes/origin/$declared"; then
        n=$(git -C "$spath" rev-list --count "origin/$declared..HEAD" 2>/dev/null || echo 0)
        if [ "$n" != "0" ]; then
            state="$state · $n UNPUSHED"
            mark="⬆"
            unpushed=1
        fi
    fi

    printf '   %s %-56s %-8s %-10s %s\n' \
        "$mark" "$spath" "${head:0:7}" "$sbranch" "$state"
done < <(dotfiles_submodules)

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
if [ "$drift" -eq 0 ] && [ "$detached" -eq 0 ] && [ "$unpushed" -eq 0 ]; then
    echo "✓ Everything matches its pin."
else
    if [ "$drift" -ne 0 ]; then
        echo "→ Working trees differ from pins.  just git-sync (adopt pins)  |  just git-update-submodules (move pins)"
    fi
    if [ "$unpushed" -ne 0 ]; then
        echo "→ Unpushed submodule commits. Push them BEFORE committing a pin bump, or other machines cannot fetch the pin."
    fi
    if [ "$detached" -ne 0 ]; then
        echo "→ Detached HEAD on a branch-tracking submodule. Run just git-sync before editing there."
    fi
fi
exit 0
