#!/usr/bin/env bash
#
# Fix SSH file permissions.
#
# WHY THIS EXISTS
# ---------------
# Git writes checked-out files using the process umask. On these machines the
# umask is 002, so git writes mode 664 (group-writable). SSH hard-refuses a
# group-writable config:
#
#     Bad owner or permissions on ~/.ssh/config
#
# ...and then *every* ssh and git-over-ssh command fails. Git cannot carry the
# fix itself: it only tracks the executable bit, not the full mode. So the mode
# has to be re-asserted by whatever put the file there.
#
# This broke on 2026-08-24: a submodule fast-forward rewrote the ssh config and
# silently locked the machine out of git-over-ssh. The chmod used to be
# copy-pasted inside stow.sh only, which meant no submodule code path could
# reach it. This script is the single source of truth; every path that checks
# out or relinks the ssh_common config calls it:
#
#     just stow
#     just git-sync
#     just git-sync-submodules
#     just git-update-submodules
#     just doctor-fix-ssh-perms   (standalone)
#
# See docs/submodules.md.

set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# --quiet: report repairs, but stay silent when there was nothing to do. Used
# for the pre-flight call, so a healthy machine does not get a duplicate line.
QUIET=0
if [ "${1:-}" = "--quiet" ]; then
    QUIET=1
fi

changed=0

# Print the effective mode of a path, following symlinks (we care about the
# mode of the real file, since ~/.ssh/config is usually a stow symlink).
_mode_of() {
    if [ "$(uname)" = "Darwin" ]; then
        stat -f "%Lp" -L "$1" 2>/dev/null
    else
        stat -c "%a" -L "$1" 2>/dev/null
    fi
}

_fix_mode() {
    local target="$1" want="$2" have shown
    [ -e "$target" ] || return 0

    have=$(_mode_of "$target")
    [ -n "$have" ] || return 0
    if [ "$have" = "$want" ]; then
        return 0
    fi

    # chmod follows symlinks, so this corrects the real file in the submodule.
    chmod "$want" "$target"

    shown="$target"
    case "$shown" in
        "$HOME"/*) shown="~${shown#"$HOME"}" ;;
    esac
    echo "  🔐 $shown: $have → $want"
    changed=1
}

# The repo-side file (correct it even before stow has run).
_fix_mode "$DOTFILES_DIR/configs/ssh_common/dot-ssh/config" 600

# The deployed file. Usually a symlink to the above, but may be a standalone
# bootstrap config on a machine that has not been stowed yet.
_fix_mode "$HOME/.ssh/config" 600

# SSH also refuses a group/world-writable ~/.ssh directory.
_fix_mode "$HOME/.ssh" 700

if [ "$changed" -eq 0 ] && [ "$QUIET" -eq 0 ]; then
    echo "  🔐 SSH permissions already correct"
fi
