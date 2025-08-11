#!/usr/bin/env bash
# Test Suite for Package Installer
# Tests the TOML-based package management system

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER="$SCRIPT_DIR/../scripts/install.sh"
TOML_PARSER="$SCRIPT_DIR/../scripts/toml-parser.py"

# Test counter
TESTS_RUN=0
TESTS_PASSED=0

# Test utilities
assert_command_exists() {
    local cmd="$1"
    local test_name="$2"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if command -v "$cmd" >/dev/null 2>&1; then
        echo "✓ PASS: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ FAIL: $test_name - command not found: $cmd"
    fi
}

assert_file_exists() {
    local file="$1"
    local test_name="$2"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [ -f "$file" ]; then
        echo "✓ PASS: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ FAIL: $test_name - file not found: $file"
    fi
}

# Tests
echo "🧪 Testing Package Management System"
echo "===================================="
echo ""

# Test: Required files exist
assert_file_exists "$INSTALLER" "Installer script exists"
assert_file_exists "$TOML_PARSER" "TOML parser exists"

# Test: Python 3.11+ available
echo ""
echo "Testing Python environment:"
if python3 -c 'import sys; exit(0 if sys.version_info >= (3, 11) else 1)' 2>/dev/null; then
    PYTHON_VERSION=$(python3 --version 2>&1)
    echo "✓ PASS: Python 3.11+ available - $PYTHON_VERSION"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "✗ FAIL: Python 3.11+ required for native tomllib"
fi
TESTS_RUN=$((TESTS_RUN + 1))

# Test: TOML parser can import tomllib
echo ""
echo "Testing TOML parser:"
if python3 -c 'import tomllib' 2>/dev/null; then
    echo "✓ PASS: Native tomllib available"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "✗ FAIL: Native tomllib not available"
fi
TESTS_RUN=$((TESTS_RUN + 1))

# Test: Package definitions exist
echo ""
echo "Testing package definitions:"
PACKAGE_DIR="$SCRIPT_DIR/../package-definitions"
for toml_file in cli-editors cli-utils dev-env fonts gui-apps; do
    assert_file_exists "$PACKAGE_DIR/${toml_file}.toml" "Package definition: ${toml_file}.toml"
done

# Test: TOML parser can read package files
echo ""
echo "Testing TOML parsing:"
if [ -f "$PACKAGE_DIR/cli-utils.toml" ]; then
    if python3 "$TOML_PARSER" "$PACKAGE_DIR/cli-utils.toml" --action packages --platform osx --package-manager brew >/dev/null 2>&1; then
        echo "✓ PASS: TOML parser can read package files"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ FAIL: TOML parser failed to read package files"
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
fi

# Test: Installer show-config works
echo ""
echo "Testing installer functionality:"
if DOTFILES_PLATFORM=osx bash "$INSTALLER" show-config >/dev/null 2>&1; then
    echo "✓ PASS: Installer show-config works"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "✗ FAIL: Installer show-config failed"
fi
TESTS_RUN=$((TESTS_RUN + 1))

# Summary
echo ""
echo "===================================="
echo "Test Results: $TESTS_PASSED/$TESTS_RUN passed"

if [ "$TESTS_PASSED" -eq "$TESTS_RUN" ]; then
    echo "✅ All tests passed!"
    exit 0
else
    echo "❌ Some tests failed"
    exit 1
fi