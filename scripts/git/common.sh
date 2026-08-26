#!/usr/bin/env bash
#
# Shared helpers for the `just git-*` recipes.
#
# Sourced, not executed. See scripts/git/sync.sh and scripts/git/status.sh.

# Emit "<pin-sha>\t<path>" for every submodule, one per line.
#
# NOTE: enumerated from the git INDEX (mode 160000 entries), not from
# .gitmodules. The index is the truth about what is actually a submodule;
# .gitmodules accumulates stale entries for submodules that were removed
# (it listed two dead nvim entries as of 2026-08). Reading the index means
# stale declarations simply never appear.
#
# Output is tab-separated because submodule paths contain spaces
# (e.g. "configs/alfred-settings/Library/Application Support/Alfred").
dotfiles_submodules() {
    git ls-files --stage | awk -F'\t' '
        $1 ~ /^160000 / { split($1, a, " "); print a[2] "\t" $2 }
    '
}

# Print the branch declared for a submodule path in .gitmodules, or nothing.
#
# An empty result is meaningful, not an error: submodules with no declared
# branch are vendored upstreams (spacemacs, doomemacs) where detached-at-pin
# is the correct and desired state. Only branch-declaring submodules get
# attached to a branch by git-sync.
dotfiles_submodule_branch() {
    local want="$1" key name spath
    while read -r key spath; do
        [ "$spath" = "$want" ] || continue
        name="${key#submodule.}"
        name="${name%.path}"
        git config -f .gitmodules --get "submodule.$name.branch" 2>/dev/null || true
        return 0
    done < <(git config -f .gitmodules --get-regexp '^submodule\..*\.path$' 2>/dev/null || true)
}

# Short sha, or "-" if the path is not a working repo.
dotfiles_short_sha() {
    git -C "$1" rev-parse --short=7 HEAD 2>/dev/null || echo "-"
}

# Current branch name, or "(detached)".
dotfiles_current_branch() {
    local br
    br=$(git -C "$1" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "HEAD")
    if [ "$br" = "HEAD" ]; then
        br="(detached)"
    fi
    echo "$br"
}
