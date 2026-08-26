#!/usr/bin/env bash
#
# Record moved submodules as new pins in the parent repo (PRODUCER direction)
# -> just git-bump-pins [--yes]
#
# THE INVARIANT THIS PROTECTS
# ---------------------------
# A pin is just a sha. If you commit a pin pointing at a commit that only
# exists on this machine, the parent repo is broken for everyone else: their
# `git submodule update` tries to fetch a sha the remote has never heard of and
# fails with "direct fetch of that commit failed". The repo looks fine here and
# is unusable there.
#
# So this refuses to bump a pin whose commit is not reachable from the
# submodule's remote branch. Push first (just git-push), then bump.
#
# It also only ever moves a pin FORWARD onto published work. Submodules sitting
# behind their pin are consumer-side drift, not something to record - that is
# what just git-sync is for.

set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "$DOTFILES_DIR"

# shellcheck source=scripts/git/common.sh
source "$DOTFILES_DIR/scripts/git/common.sh"

ASSUME_YES=0
if [ "${1:-}" = "--yes" ]; then
    ASSUME_YES=1
fi

READY=$(mktemp)
BLOCKED=$(mktemp)
BEHIND=$(mktemp)
trap 'rm -f "$READY" "$BLOCKED" "$BEHIND"' EXIT

echo "📌 Checking for submodules whose commit differs from its pin..."

while IFS=$'\t' read -r pin spath; do
    [ -e "$spath/.git" ] || continue

    head=$(git -C "$spath" rev-parse HEAD)
    if [ "$head" = "$pin" ]; then
        continue
    fi

    branch=$(dotfiles_submodule_branch "$spath")

    # Behind the pin: consumer drift, not a bump. Leave it alone.
    if git -C "$spath" merge-base --is-ancestor "$head" "$pin" 2>/dev/null; then
        printf '%s\n' "$spath" >> "$BEHIND"
        continue
    fi

    # Is this commit actually published? That is the whole question.
    published=0
    if [ -n "$branch" ] && git -C "$spath" show-ref --verify --quiet "refs/remotes/origin/$branch"; then
        if git -C "$spath" merge-base --is-ancestor "$head" "refs/remotes/origin/$branch" 2>/dev/null; then
            published=1
        fi
    fi

    if [ "$published" -eq 1 ]; then
        printf '%s\t%s\t%s\n' "$spath" "$pin" "$head" >> "$READY"
    else
        printf '%s\t%s\n' "$spath" "${branch:-<no declared branch>}" >> "$BLOCKED"
    fi
done < <(dotfiles_submodules)

# ── Refuse if anything is unpublished ────────────────────────────────────────
if [ -s "$BLOCKED" ]; then
    echo ""
    echo "❌ Refusing to bump: these commits are not on their remote branch yet."
    echo "   Pinning them would break every other machine's submodule update."
    echo ""
    while IFS=$'\t' read -r spath branch; do
        printf '   %s\n' "$spath"
        printf '     HEAD is not reachable from origin/%s\n' "$branch"
    done < "$BLOCKED"
    echo ""
    echo "   Publish them first:  just git-push"
    exit 1
fi

if [ -s "$BEHIND" ]; then
    echo ""
    echo "ℹ  Behind their pin (consumer drift, not a bump — run just git-sync):"
    sed 's/^/     /' "$BEHIND"
fi

if [ ! -s "$READY" ]; then
    echo "   ✓ Nothing to bump — every submodule matches its pin"
    exit 0
fi

# ── Build the commit ─────────────────────────────────────────────────────────
echo ""
echo "The following pins will move:"
echo ""

MSG=$(mktemp)
trap 'rm -f "$READY" "$BLOCKED" "$BEHIND" "$MSG"' EXIT

{
    echo "chore(submodules): bump pins"
    echo ""
} > "$MSG"

while IFS=$'\t' read -r spath pin head; do
    n=$(git -C "$spath" rev-list --count "$pin..$head")
    printf '   %s\n     %s → %s (%s commit(s))\n' "$spath" "${pin:0:7}" "${head:0:7}" "$n"
    git -C "$spath" log --oneline "$pin..$head" | sed 's/^/       /'
    echo ""

    {
        printf -- '- %s: %s → %s\n' "$spath" "${pin:0:7}" "${head:0:7}"
        git -C "$spath" log --format='    %h %s' "$pin..$head"
    } >> "$MSG"
done < "$READY"

if [ "$ASSUME_YES" -eq 0 ]; then
    if [ ! -t 0 ]; then
        echo "❌ Not a terminal and --yes not given; refusing to commit unattended."
        exit 1
    fi
    read -r -p "Commit these pin bumps? (y/N): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "❌ Cancelled (nothing staged)."
        exit 1
    fi
fi

# Stage ONLY the submodule paths. Never `git add -A` here: the parent repo
# routinely has unrelated work in progress, and silently sweeping it into a
# "bump pins" commit is how unrelated changes get lost in history.
while IFS=$'\t' read -r spath _pin _head; do
    git add -- "$spath"
done < "$READY"

git commit -q -F "$MSG"
echo ""
echo "✅ $(git rev-parse --short HEAD) $(git log -1 --format=%s)"
echo ""
echo "Next step:"
echo "  just git-push"
