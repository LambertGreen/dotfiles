#!/usr/bin/env bash
# Apply macOS file associations from ~/.config/duti/defaults.duti
#
# Prerequisites:
#   - macOS
#   - duti installed via Homebrew (see Brewfile)
#   - ~/.config/duti/defaults.duti stowed from configs/duti_osx
#
# Usage:
#   bash scripts/os-post-install/macos/apply-file-associations.sh
#   just apply-file-associations
#
# Dry-run (show what would happen without applying):
#   LGREEN_APPLY_FA_DRYRUN=1 bash scripts/os-post-install/macos/apply-file-associations.sh

set -euo pipefail

CONFIG="${HOME}/.config/duti/defaults.duti"
DRYRUN="${LGREEN_APPLY_FA_DRYRUN:-0}"

if [ "$(uname)" != "Darwin" ]; then
    echo "❌ macOS-only (detected $(uname))"
    exit 1
fi

if ! command -v duti >/dev/null 2>&1; then
    echo "❌ duti not installed. Add 'brew \"duti\"' to your Brewfile and run: just install"
    exit 1
fi

if [ ! -f "$CONFIG" ]; then
    echo "❌ Config not found: $CONFIG"
    echo "   Did you 'just stow'? The duti_osx package provides this file."
    exit 1
fi

echo "📄 Config: $CONFIG"
echo ""
echo "Current state (before apply):"

# Extract each rule from the config and query current handler for each
# duti config lines look like:  <bundle-id> <UTI-or-ext> <role>
while IFS= read -r line; do
    # Skip comments and blank lines
    case "$line" in
        \#*|"") continue ;;
    esac
    # shellcheck disable=SC2086
    set -- $line
    [ $# -ge 2 ] || continue
    target_bundle="$1"
    ut_or_ext="$2"

    # duti -x can query by extension; not directly by UTI. If it's an extension
    # (starts with `.` or short alphanumeric), query with duti -x. Otherwise
    # print the UTI target and skip the query.
    if [[ "$ut_or_ext" == .* ]]; then
        ext="${ut_or_ext#.}"
        current=$(duti -x "$ext" 2>/dev/null | head -1 || true)
        printf "  %-14s  current: %s → target: %s\n" ".$ext" "${current:-<none>}" "$target_bundle"
    else
        printf "  %-14s  target:  %s\n" "$ut_or_ext" "$target_bundle"
    fi
done < "$CONFIG"

echo ""
if [ "$DRYRUN" = "1" ]; then
    echo "🔍 DRY-RUN: skipping apply (LGREEN_APPLY_FA_DRYRUN=1)"
    exit 0
fi

echo "🚀 Applying with duti..."
duti "$CONFIG"
echo "✅ Applied"

echo ""
echo "State after apply:"
while IFS= read -r line; do
    case "$line" in
        \#*|"") continue ;;
    esac
    # shellcheck disable=SC2086
    set -- $line
    [ $# -ge 2 ] || continue
    ut_or_ext="$2"
    if [[ "$ut_or_ext" == .* ]]; then
        ext="${ut_or_ext#.}"
        current=$(duti -x "$ext" 2>/dev/null | head -1 || true)
        printf "  %-14s  → %s\n" ".$ext" "${current:-<none>}"
    fi
done < "$CONFIG"
