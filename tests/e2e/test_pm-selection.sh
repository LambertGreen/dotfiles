#!/usr/bin/env bash
# Simple test of PM selection interface

set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Simple logging functions for testing
log_debug() { echo "[DEBUG] $1"; }
log_info() { echo "[INFO] $1"; }
log_warn() { echo "[WARN] $1"; }

source "${DOTFILES_ROOT}/scripts/package-management/shared/pm-detection.sh"

echo "🧪 Testing Interactive PM Selection Interface"
echo "=============================================="

# Test system PMs
echo ""
echo "1️⃣ Testing SYSTEM package manager selection:"
readarray -t sys_pms < <(detect_package_managers "system")
echo "   Detected: ${sys_pms[*]}"

if [[ ${#sys_pms[@]} -gt 0 ]]; then
    echo ""
    echo "Interactive selection test (should show numbered list):"
    readarray -t selected_sys < <(select_package_managers "system" "${sys_pms[@]}")
    echo "   You selected: ${selected_sys[*]}"
fi

echo ""
echo "✅ Testing complete!"
echo ""
echo "📝 To test fully interactive mode, run this script manually:"
echo "   bash test-pm-selection.sh"
