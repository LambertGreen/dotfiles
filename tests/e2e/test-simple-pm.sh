#!/usr/bin/env bash
# Test simple PM detection and selection

# Add test directory to PATH for fake PMs
export PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd):$PATH"

# Source the simple detection and selection
source ../scripts/package-management/shared/simple-pm-detect.sh
source ../scripts/package-management/shared/simple-pm-select.sh

echo "🧪 Testing Simple PM Detection & Selection"
echo "=========================================="
echo ""

echo "1. Testing detection:"
echo "---------------------"
echo "System PMs detected:"
detect_pms "system"
echo ""

echo "Dev PMs detected:"
detect_pms "dev"
echo ""

echo "Test PMs detected:"
detect_pms "test"
echo ""

echo "2. Testing selection (test context):"
echo "------------------------------------"
readarray -t test_pms < <(detect_pms "test")
if [[ ${#test_pms[@]} -gt 0 ]]; then
    echo "Available test PMs: ${test_pms[*]}"
    readarray -t selected < <(select_pms "test" "${test_pms[@]}")
    echo "Selected: ${selected[*]}"
else
    echo "No test PMs found (run from test directory)"
fi
