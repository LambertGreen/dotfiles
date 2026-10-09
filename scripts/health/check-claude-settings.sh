#!/usr/bin/env bash
# Warn when ~/.claude/settings.json is not a symlink into the settings package
# (ai_claude_my / ai_claude_work) that this machine class stows.
#
# Claude Code rewrites that file itself (/config, autoMode edits). Stowed, those
# writes land in the repo and show up as `git diff`; as a plain file they drift
# silently. On 2026-10-08 both Macs were found with a plain file.
#
# Warn-only: always exits 0. TEST_HOME and DOTFILES_DIR override for tests.

set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
TEST_HOME="${TEST_HOME:-$HOME}"

if [ -f "$TEST_HOME/.dotfiles.env" ]; then
    # shellcheck disable=SC1091
    source "$TEST_HOME/.dotfiles.env"
fi

class="${DOTFILES_MACHINE_CLASS:-}"
if [ -z "$class" ]; then
    echo "  ⏭️  No machine class configured (run: just configure); skipping"
    exit 0
fi

stow_file="$DOTFILES_DIR/machine-classes/$class/stow/stow.txt"
if [ ! -f "$stow_file" ]; then
    echo "  ⏭️  $stow_file not found; skipping"
    exit 0
fi

pkg=""
for candidate in ai_claude_my ai_claude_work; do
    if grep -qx "$candidate" "$stow_file"; then
        pkg="$candidate"
        break
    fi
done
if [ -z "$pkg" ]; then
    echo "  ⏭️  $class stows no Claude settings package; skipping"
    exit 0
fi

target="$TEST_HOME/.claude/settings.json"
want_suffix="configs/$pkg/dot-claude/settings.json"
readme="configs/$pkg/README.md"

if [ -L "$target" ]; then
    link=$(readlink "$target")
    if [[ "$link" != *"$want_suffix" ]]; then
        echo "  ⚠ ~/.claude/settings.json points at $link, not $pkg"
        echo "    See $readme"
    elif [ ! -e "$target" ]; then
        echo "  ⚠ ~/.claude/settings.json is a broken symlink ($link)"
        echo "    Restow: just stow"
    else
        echo "  ✓ ~/.claude/settings.json → $pkg"
    fi
elif [ -e "$target" ]; then
    echo "  ⚠ ~/.claude/settings.json is a plain file, not stowed from $pkg"
    echo "    Adopt it before stowing (just stow would back it up and replace it): see $readme"
else
    echo "  ⚠ ~/.claude/settings.json is missing; stow it: just stow"
fi
