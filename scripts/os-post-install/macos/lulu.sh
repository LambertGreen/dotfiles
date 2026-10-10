#!/usr/bin/env bash
# LuLu (Objective-See firewall) config: snapshot, restore steps, drift check.
#
# LuLu's data dir is root-owned and read by its system extension, so nothing
# here writes there or symlinks into it. Model: snapshot + restore through
# LuLu's own UI (Rules → Import, Settings). Reading needs no root.
#
#   preferences  machine-classes/<class>/lulu/preferences.json   (tracked)
#   rules        $LULU_RULES_SNAPSHOT                              (NOT tracked)
#
# Rules list every app and the hosts it may reach, and this repo is public, so
# the rules snapshot lives outside it. Default:
#   ${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/lulu/rules.json
# Point LULU_RULES_SNAPSHOT (env or ~/.dotfiles.env) at a private repo checkout
# or similar to keep it versioned.
#
# Usage:
#   bash scripts/os-post-install/macos/lulu.sh export [--all]
#   bash scripts/os-post-install/macos/lulu.sh import
#   bash scripts/os-post-install/macos/lulu.sh check

set -euo pipefail

cmd="${1:-}"
shift || true

if [ "$(uname)" != "Darwin" ]; then
    echo "⏭️  LuLu is macOS-only"
    exit 0
fi

if [ -f "$HOME/.dotfiles.env" ]; then
    # shellcheck disable=SC1091
    . "$HOME/.dotfiles.env"
fi

# The checkout this script lives in (a worktree writes its own snapshot).
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
CLASS="${DOTFILES_MACHINE_CLASS:-}"
PREFS_SNAPSHOT="$DOTFILES_DIR/machine-classes/$CLASS/lulu/preferences.json"
RULES_SNAPSHOT="${LULU_RULES_SNAPSHOT:-${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/lulu/rules.json}"
LULU_PY=(python3 "$DOTFILES_DIR/src/dotfiles_pm/lulu_config.py")

if [ -z "$CLASS" ]; then
    echo "❌ DOTFILES_MACHINE_CLASS unset (run: just configure)"
    exit 1
fi

if [ ! -d "/Library/Objective-See/LuLu" ]; then
    echo "⏭️  LuLu not installed on this machine (no /Library/Objective-See/LuLu)"
    exit 0
fi

case "$cmd" in
    export)
        "${LULU_PY[@]}" export --prefs-out "$PREFS_SNAPSHOT" --rules-out "$RULES_SNAPSHOT" "$@"
        echo ""
        echo "Review prefs:  git -C \"$DOTFILES_DIR\" diff -- machine-classes/$CLASS/lulu/"
        ;;
    import)
        "${LULU_PY[@]}" restore-steps --prefs-snapshot "$PREFS_SNAPSHOT" --rules-snapshot "$RULES_SNAPSHOT"
        ;;
    check)
        if [ ! -d "$(dirname "$PREFS_SNAPSHOT")" ]; then
            echo "⏭️  No LuLu snapshot for class $CLASS (machine-classes/$CLASS/lulu/)"
            exit 0
        fi
        "${LULU_PY[@]}" check --prefs-snapshot "$PREFS_SNAPSHOT" --rules-snapshot "$RULES_SNAPSHOT" "$@"
        ;;
    *)
        echo "usage: $0 {export [--all]|import|check}" >&2
        exit 2
        ;;
esac
