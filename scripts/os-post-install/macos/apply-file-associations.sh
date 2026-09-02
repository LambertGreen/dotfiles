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
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

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

echo ""
echo "State after apply:"

# duti exits 0 even when LaunchServices silently refuses the change - most
# often because the target bundle id is not installed. Verify each rule landed
# rather than trusting the exit code; otherwise this reports "Applied" while
# printing evidence to the contrary.
unapplied=0
while IFS= read -r line; do
    case "$line" in
        \#*|"") continue ;;
    esac
    # shellcheck disable=SC2086
    set -- $line
    [ $# -ge 2 ] || continue
    target_bundle="$1"
    ut_or_ext="$2"
    if [[ "$ut_or_ext" == .* ]]; then
        ext="${ut_or_ext#.}"
        # `duti -x` prints: app name / app path / bundle id
        current_app=$(duti -x "$ext" 2>/dev/null | sed -n '1p' || true)
        current_bundle=$(duti -x "$ext" 2>/dev/null | sed -n '3p' || true)
        if [ "$current_bundle" = "$target_bundle" ]; then
            printf "  %-14s  ✅ → %s\n" ".$ext" "${current_app:-<none>}"
        else
            unapplied=$((unapplied + 1))
            printf "  %-14s  ❌ → %s (wanted %s)\n" \
                ".$ext" "${current_app:-<none>}" "$target_bundle"
        fi
    fi
done < "$CONFIG"

echo ""
if [ "$unapplied" -gt 0 ]; then
    echo "❌ $unapplied association(s) did not apply."
    echo ""
    echo "   Two usual causes:"
    echo "   1. The target app isn't installed. Check the machine-class Brewfile."
    echo "   2. It IS installed but LaunchServices hasn't registered it yet —"
    echo "      common right after 'just install' on a fresh machine, since a"
    echo "      cask that has never been launched may not be indexed."
    echo ""
    echo "   Diagnose:  osascript -e 'id of app \"<App Name>\"'"
    echo "   Register:  $LSREGISTER -f \"\$HOME/Applications/<App Name>.app\""
    echo "   ...then re-run: just apply-file-associations"
    exit 1
fi

echo "✅ Applied"
