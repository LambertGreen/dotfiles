#!/usr/bin/env bash
# Quick test of the interactive PM selection

source ./scripts/package-management/shared/pm-detection.sh

echo "🧪 TESTING INTERACTIVE PM SELECTION"
echo "=================================="

# Test system PMs
echo ""
echo "1. Testing SYSTEM package manager detection:"
sys_pms=($(detect_package_managers "system"))
echo "   Detected: ${sys_pms[*]}"

# Force interactive mode by simulating terminal
if [[ -t 0 ]] && [[ -t 1 ]]; then
    echo "   ✅ Running in interactive terminal mode"
else
    echo "   ⚠️ Not in interactive mode (stdin/stdout not terminals)"
    echo "   📝 To test interactively, run: bash test-interactive.sh"
fi

echo ""
echo "2. Testing DEV package manager detection:"
dev_pms=($(detect_package_managers "dev"))
echo "   Detected: ${dev_pms[*]}"

echo ""
echo "3. Testing APP package manager detection:"
app_pms=($(detect_package_managers "app"))
echo "   Detected: ${app_pms[*]}"

echo ""
echo "🎯 DETECTED TOTALS:"
echo "   System: ${#sys_pms[@]} PMs (${sys_pms[*]})"
echo "   Dev: ${#dev_pms[@]} PMs (${dev_pms[*]})"
echo "   App: ${#app_pms[@]} PMs (${app_pms[*]})"
echo ""
echo "📋 To see interactive selection, run:"
echo "   just check-packages"
echo "   (and wait for prompts or press numbers)"
