#!/usr/bin/env bash
# Warn when ~/.claude is not the folder link into the package this machine class
# stows (ai_claude_my / ai_claude_work), or when that package has uncommitted changes.
#
# ~/.claude is one stow folder link into configs/<pkg>/dot-claude, a private
# submodule (B25). AI tools and corp apps replace files by writing a temp file and
# renaming it over the original, which breaks a per-file symlink. On 2026-10-09 the work
# Mac's stowed settings.json was a plain file again two minutes after it was stowed.
# Inside a linked folder the same rename lands in the repo, so it shows up here as
# uncommitted changes instead of silent drift.
#
# Lines starting with ⚠ are what `just sync` (Council) reports as WARN.
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
    echo "  ⏭️  $class stows no Claude folder package; skipping"
    exit 0
fi

target="$TEST_HOME/.claude"
want_suffix="configs/$pkg/dot-claude"
readme="configs/$pkg/README.md"

if [ -L "$target" ]; then
    link=$(readlink "$target")
    if [[ "${link%/}" != *"$want_suffix" ]]; then
        echo "  ⚠ ~/.claude points at $link, not $pkg"
        echo "    See $readme"
        exit 0
    elif [ ! -d "$target" ]; then
        echo "  ⚠ ~/.claude is a broken folder link ($link)"
        echo "    Initialize the submodule (just git-sync), then: just stow"
        exit 0
    fi
    echo "  ✓ ~/.claude → $pkg (folder link)"
elif [ -d "$target" ]; then
    echo "  ⚠ ~/.claude is a real directory, not the folder link into $pkg"
    echo "    Migrate it with no Claude session running: scripts/claude/migrate-dir.sh (see $readme)"
    exit 0
elif [ -e "$target" ]; then
    echo "  ⚠ ~/.claude is not a directory"
    exit 0
else
    echo "  ⚠ ~/.claude is missing; stow it: just stow"
    exit 0
fi

dir=$(cd "$target" && pwd -P)
if [ ! -e "$dir/.git" ]; then
    echo "  ⚠ $want_suffix is not an initialized submodule; run: just git-sync"
    exit 0
fi

dirty=$(git -C "$dir" status --porcelain --untracked-files=all 2>/dev/null || echo "?? (git status failed)")
if [ -n "$dirty" ]; then
    names=$(printf '%s\n' "$dirty" | cut -c4- | head -n 3 | paste -sd ' ' -)
    count=$(printf '%s\n' "$dirty" | wc -l | tr -d ' ')
    echo "  ⚠ ~/.claude has $count uncommitted change(s): $names"
    echo "    Something rewrote a curated file. Review: git -C $want_suffix diff (commit or revert)"
else
    echo "  ✓ ~/.claude curated files match the dot-claude repo"
fi

# New top-level names stay hidden by the allow-list .gitignore. That is safe, but a new
# writer is worth knowing about, so name anything this script has not seen before.
unknown=()
for entry in "$dir"/* "$dir"/.[!.]*; do
    [ -e "$entry" ] || [ -L "$entry" ] || continue
    name=$(basename "$entry")
    case "$name" in
        .git | .gitignore | README.md | CLAUDE.md | settings.json) ;;
        projects | sessions | session-env | history.jsonl | .credentials.json | plugins) ;;
        file-history | paste-cache | shell-snapshots | todos | statsig | ide | debug) ;;
        cache | telemetry | feedback | backups | stats-cache.json | skills | hooks) ;;
        statusline.sh | settings.local.json | settings.json.* | .last-* | .DS_Store) ;;
        *) unknown+=("$name") ;;
    esac
done
if [ ${#unknown[@]} -gt 0 ]; then
    echo "  ℹ New in ~/.claude (git-ignored; review what writes it): ${unknown[*]}"
fi
