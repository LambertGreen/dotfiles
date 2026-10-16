#!/usr/bin/env bash
# Report-only stow dry run: would `just stow` change anything? -> just stow-check
#
# Contract (the Council's `just sync` calls this; ai_council src/council/sync.py):
#   exit 0   stow would change nothing
#   exit 1   it would: stdout names each change, one per line, "<package>: <stow line>"
#            (LINK: / UNLINK: / MKDIR: / RMDIR: as stow -v prints them, or CONFLICT <why>)
#   exit 2   could not tell (stderr says why)
#
# Same package list and --no-folding marker rule as stow.sh (scripts/stow/packages.sh),
# but it never writes:
#   - `stow -n -v` from configs/, so configs/.stowrc applies (run from anywhere else,
#     .stowrc itself shows up as a false LINK: seen 2026-10-15)
#   - no --restow: a restow always reports UNLINK+LINK, even when nothing would change
#   - no log file, no shell-rc backups, no conflict resolution
#
# DOTFILES_DIR overrides the repo for tests; HOME is the stow target.

set -uo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
# shellcheck source=packages.sh
source "$(dirname "${BASH_SOURCE[0]}")/packages.sh"

cannot_tell() {
    echo "stow-check: $*" >&2
    exit 2
}

[ -f "$HOME/.dotfiles.env" ] || cannot_tell "\$HOME/.dotfiles.env missing (run: just configure)"
# shellcheck disable=SC1091
source "$HOME/.dotfiles.env"
class="${DOTFILES_MACHINE_CLASS:-}"
[ -n "$class" ] || cannot_tell "DOTFILES_MACHINE_CLASS not set (run: just configure)"
stow_file="$DOTFILES_DIR/machine-classes/$class/stow/stow.txt"
[ -f "$stow_file" ] || cannot_tell "$stow_file not found"
case "$(uname -s)" in
    MINGW* | MSYS*) cannot_tell "not supported on Windows (stow runs through MSYS2 there)" ;;
esac
command -v stow >/dev/null 2>&1 || cannot_tell "stow not on PATH"
cd "$DOTFILES_DIR/configs" || cannot_tell "cannot cd to $DOTFILES_DIR/configs"

changed=0
while IFS= read -r pkg; do
    [ -d "$pkg" ] || continue # stow.sh skips a listed package with no directory too

    # shellcheck disable=SC2046  # empty or one word, by design
    out=$(stow -n -v --dotfiles --target="$HOME" $(stow_fold_opts "$pkg") "$pkg" 2>&1)
    rc=$?

    conflict=0
    while IFS= read -r line; do
        case "$line" in
            LINK:* | UNLINK:* | MKDIR:* | RMDIR:*)
                printf '%s: %s\n' "$pkg" "$line"
                changed=1
                ;;
            *'* '*) # stow's conflict bullets: "  * cannot stow ... over existing target ..."
                printf '%s: CONFLICT %s\n' "$pkg" "${line#*\* }"
                changed=1
                conflict=1
                ;;
        esac
    done <<< "$out"

    if [ "$rc" -ne 0 ] && [ "$conflict" -eq 0 ]; then
        cannot_tell "stow failed for $pkg: $(printf '%s\n' "$out" | tail -n 1)"
    fi
done < <(stow_packages "$stow_file")

exit "$changed"
