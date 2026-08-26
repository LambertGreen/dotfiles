#!/usr/bin/env bash
#
# Bring this machine current with the remote (the CONSUMER direction).
#
#   scripts/git/sync.sh              -> just git-sync             (repo + submodules)
#   scripts/git/sync.sh --submodules -> just git-sync-submodules  (submodules only)
#
# CONSUMER vs PRODUCER
# --------------------
# Submodule work comes in two directions and conflating them is how machines
# drift apart:
#
#   consumer (this script)  pins are the truth -> move the working trees TO the
#                           pins. Never moves a pin.
#   producer (update.sh)    the remote branch is the truth -> move the working
#                           trees PAST the pins, then you commit the new pins.
#
# WHY NOT JUST `git submodule update`
# -----------------------------------
# Plain `git submodule update` lands each submodule at its pin as a DETACHED
# HEAD. That is legitimate git, but in a dotfiles repo you routinely edit inside
# submodules, and a commit made on a detached HEAD is stranded off-branch - the
# root cause of the 2026-08 ssh config drift. So for every submodule that
# declares a branch in .gitmodules, this script also ATTACHES that branch at the
# pin, leaving you on a branch and ready to edit. Submodules with no declared
# branch are vendored upstreams and stay detached, which is correct for them.

set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "$DOTFILES_DIR"

# shellcheck source=scripts/git/common.sh
source "$DOTFILES_DIR/scripts/git/common.sh"

SUBMODULES_ONLY=0
if [ "${1:-}" = "--submodules" ]; then
    SUBMODULES_ONLY=1
fi

BEFORE=$(mktemp)
NOTES=$(mktemp)
trap 'rm -f "$BEFORE" "$NOTES"' EXIT

failed=0

# Look up a path's pre-sync sha. Exact field match, not a substring search:
# ".../dot-config/nvim" is a prefix of ".../dot-config/nvim-lazy".
_before_sha() {
    awk -F'\t' -v p="$1" '$2 == p { print $1; exit }' "$BEFORE"
}

# ─────────────────────────────────────────────────────────────────────────────
# 0. Pre-flight: SSH permissions
# ─────────────────────────────────────────────────────────────────────────────
# This MUST run before the pull, not only after the checkouts. Every remote
# here is git-over-ssh, so a group-writable ssh config makes step 1 fail with
# "Bad owner or permissions" — and a repair that only ran at the end would
# never be reached. That is exactly how this deadlocks: the previous checkout
# breaks the mask, and the next git-sync then cannot pull to fix it.
bash "$DOTFILES_DIR/scripts/ssh/fix-perms.sh" --quiet

# ─────────────────────────────────────────────────────────────────────────────
# 1. Superproject
# ─────────────────────────────────────────────────────────────────────────────
if [ "$SUBMODULES_ONLY" -eq 0 ]; then
    echo "⬇️  Pulling dotfiles repo..."
    repo_before=$(git rev-parse HEAD)

    # --ff-only: never create a surprise merge commit on a config repo. If this
    # refuses, you have local commits and want to look before you leap.
    if ! git pull --ff-only 2>&1 | sed 's/^/   /'; then
        echo ""
        echo "   ❌ Pull was not a fast-forward."
        echo "      You have local commits, or the branch diverged. Inspect with:"
        echo "        just git-status"
        exit 1
    fi

    repo_after=$(git rev-parse HEAD)
    if [ "$repo_before" = "$repo_after" ]; then
        echo "   ✓ Already up to date"
    else
        echo "   ✓ ${repo_before:0:7} → ${repo_after:0:7}"
        git log --oneline "$repo_before..$repo_after" | sed 's/^/     /'
    fi
    echo ""
fi

# ─────────────────────────────────────────────────────────────────────────────
# 2. Submodules → pins
# ─────────────────────────────────────────────────────────────────────────────
echo "🔗 Syncing submodules to their pins..."

# Snapshot current HEADs so we can report what actually moved.
while IFS=$'\t' read -r _pin spath; do
    [ -d "$spath/.git" ] || [ -f "$spath/.git" ] || continue
    printf '%s\t%s\n' "$(dotfiles_short_sha "$spath")" "$spath" >> "$BEFORE"
done < <(dotfiles_submodules)

# sync: pick up URL changes from .gitmodules (personal-vs-work ssh host aliases
# have been rewritten more than once).
git submodule sync --recursive --quiet

# No --force: a submodule with uncommitted work should REFUSE to be checked
# out, not have that work silently discarded.
if ! git submodule update --init --recursive 2>&1 | sed 's/^/   /'; then
    echo "   ⚠️  One or more submodules could not be updated (see above)."
    echo "      Usually local edits in the way - commit, stash, or discard them."
    failed=1
fi

# ─────────────────────────────────────────────────────────────────────────────
# 3. Attach tracked branches at the pin
# ─────────────────────────────────────────────────────────────────────────────
# Returns a one-word status describing what it did.
attach_branch() {
    local spath="$1" pin="$2" branch="$3"
    local tip

    if git -C "$spath" show-ref --verify --quiet "refs/heads/$branch"; then
        tip=$(git -C "$spath" rev-parse "refs/heads/$branch")

        if [ "$tip" = "$pin" ]; then
            git -C "$spath" checkout --quiet "$branch"
            echo "on"

        elif git -C "$spath" merge-base --is-ancestor "$tip" "$pin"; then
            # Local branch is BEHIND the pin. Ancestry is verified, so moving
            # the branch pointer up to the pin is a pure fast-forward and
            # cannot lose a commit. (This was the state on all five drifted
            # submodules on 2026-08-24.)
            git -C "$spath" branch --force "$branch" "$pin"
            git -C "$spath" checkout --quiet "$branch"
            echo "ff"

        elif git -C "$spath" merge-base --is-ancestor "$pin" "$tip"; then
            # Branch is AHEAD of the pin: you cannot be on the branch AND at
            # the pin. Detached-at-pin is the honest answer - the pin is what
            # the parent repo says this machine should have. Bumping the pin is
            # a deliberate act: just git-update-submodules.
            echo "ahead"

        else
            echo "diverged"
        fi
    else
        # No local branch yet (fresh clone). Create it at the pin.
        git -C "$spath" checkout --quiet -b "$branch"
        if git -C "$spath" show-ref --verify --quiet "refs/remotes/origin/$branch"; then
            git -C "$spath" branch --quiet --set-upstream-to="origin/$branch" "$branch" >/dev/null 2>&1 || true
        fi
        echo "created"
    fi
}

moved=0
while IFS=$'\t' read -r pin spath; do
    [ -d "$spath/.git" ] || [ -f "$spath/.git" ] || continue

    before=$(_before_sha "$spath")
    after=$(dotfiles_short_sha "$spath")

    branch=$(dotfiles_submodule_branch "$spath")

    if [ -n "$branch" ]; then
        head_now=$(git -C "$spath" rev-parse HEAD 2>/dev/null || echo "")
        if [ "$head_now" = "$pin" ]; then
            result=$(attach_branch "$spath" "$pin" "$branch")
            case "$result" in
                ahead)
                    # Two very different situations look identical here, so
                    # distinguish them: are those extra commits published?
                    if git -C "$spath" show-ref --verify --quiet "refs/remotes/origin/$branch" &&
                       git -C "$spath" merge-base --is-ancestor \
                           "refs/heads/$branch" "refs/remotes/origin/$branch" 2>/dev/null; then
                        # Published: the branch is just tracking an upstream
                        # that moved on, and we pin an older commit on purpose
                        # (vendored repos like spacemacs). Nothing is wrong.
                        printf '   ℹ %s: pinned behind %s on purpose — detached at pin.\n' \
                            "$spath" "$branch" >> "$NOTES"
                        printf '     To adopt the newer upstream: just git-update-submodules\n' >> "$NOTES"
                    else
                        # Unpublished: real local work that no other machine
                        # can see. This is worth shouting about.
                        printf '   ⚠ %s: local %s has UNPUSHED commits ahead of the pin — detached at pin.\n' \
                            "$spath" "$branch" >> "$NOTES"
                        printf '     Publish first: cd "%s" && git push, then just git-update-submodules\n' \
                            "$spath" >> "$NOTES"
                    fi
                    ;;
                diverged)
                    printf '   ⚠ %s: local %s has diverged from the pin — staying detached at pin.\n' \
                        "$spath" "$branch" >> "$NOTES"
                    ;;
            esac
        else
            # update failed for this one; do not attach a branch at the wrong commit.
            printf '   ⚠ %s: not at its pin, branch not attached.\n' "$spath" >> "$NOTES"
        fi
    fi

    if [ "$before" != "$after" ]; then
        printf '   %-52s %s → %s  (%s)\n' \
            "$spath" "${before:--}" "$after" "$(dotfiles_current_branch "$spath")"
        moved=1
    fi
done < <(dotfiles_submodules)

if [ "$moved" -eq 0 ]; then
    echo "   ✓ All submodules already at their pins"
fi
if [ -s "$NOTES" ]; then
    echo ""
    cat "$NOTES"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 4. Re-assert SSH permissions
# ─────────────────────────────────────────────────────────────────────────────
# Must run AFTER any checkout: git rewrites files using the umask (002 here ->
# mode 664) and ssh refuses a group-writable config. See scripts/ssh/fix-perms.sh.
echo ""
bash "$DOTFILES_DIR/scripts/ssh/fix-perms.sh"

# ─────────────────────────────────────────────────────────────────────────────
# 5. What to do next
# ─────────────────────────────────────────────────────────────────────────────
if [ "$moved" -eq 1 ]; then
    echo ""
    echo "Next steps:"
    echo "  just stow                # link any new/renamed config files"
    while IFS=$'\t' read -r _pin spath; do
        before=$(_before_sha "$spath")
        after=$(dotfiles_short_sha "$spath")
        if [ "$before" = "$after" ]; then
            continue
        fi
        case "$spath" in
            *hammerspoon*) echo "  reload Hammerspoon       # $spath changed" ;;
            *emacs*)       echo "  restart Emacs            # $spath changed" ;;
            *nvim*)        echo "  restart Neovim           # $spath changed" ;;
            *dot-ssh*)     echo "  (ssh config updated — permissions re-asserted above)" ;;
        esac
    done < <(dotfiles_submodules)
fi

exit "$failed"
