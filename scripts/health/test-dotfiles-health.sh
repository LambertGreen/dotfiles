#!/usr/bin/env bash

set -euo pipefail

# Test framework for dotfiles health check
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HEALTH_CHECK_LIBRARY="$SCRIPT_DIR/dotfiles-health.sh"

# Create test runtime directory
TEST_ROOT="$PROJECT_ROOT/.runtime_testing"
mkdir -p "$TEST_ROOT"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
setup_test() {
    local test_name="$1"
    echo -e "\n🧪 Running test: $test_name"

    # Clean up previous test
    rm -rf "$TEST_ROOT/test_env"
    mkdir -p "$TEST_ROOT/test_env"

    # Set up test environment
    export TEST_HOME="$TEST_ROOT/test_env/home"
    export DOTFILES_DIR="$TEST_ROOT/test_env/dotfiles"

    # Create basic directory structure
    mkdir -p "$TEST_HOME"
    mkdir -p "$DOTFILES_DIR/.git"
    mkdir -p "$DOTFILES_DIR/configs"

    # Initialize git repo
    cd "$DOTFILES_DIR"
    git init --quiet
    git config user.email "test@example.com"
    git config user.name "Test User"
    touch README.md
    git add README.md
    git commit -m "Initial commit" --quiet
    cd - >/dev/null
}

run_health_check() {
    # Capture output and exit code
    local output
    local exit_code

    output=$(TEST_MODE=1 TEST_HOME="$TEST_HOME" DOTFILES_DIR="$DOTFILES_DIR" bash -c "source '$HEALTH_CHECK_LIBRARY' && dotfiles_health_check" 2>&1) || exit_code=$?

    echo "$output"
    return ${exit_code:-0}
}

assert_contains() {
    local output="$1"
    local expected="$2"
    local test_desc="${3:-contains '$expected'}"

    TESTS_RUN=$((TESTS_RUN + 1))
    if echo "$output" | grep -q "$expected"; then
        echo -e "${GREEN}✓${NC} $test_desc"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} $test_desc"
        echo "  Expected to find: $expected"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_exit_code() {
    local actual="$1"
    local expected="$2"
    local test_desc="${3:-exit code is $expected}"

    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ "$actual" -eq "$expected" ]]; then
        echo -e "${GREEN}✓${NC} $test_desc"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} $test_desc"
        echo "  Expected: $expected, Got: $actual"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test 1: Clean new system
test_new_system() {
    setup_test "Clean new system"

    # Create new system symlinks
    mkdir -p "$DOTFILES_DIR/configs/git"
    echo "gitconfig content" > "$DOTFILES_DIR/configs/git/dot-gitconfig"
    ln -s "$DOTFILES_DIR/configs/git/dot-gitconfig" "$TEST_HOME/.gitconfig"

    mkdir -p "$DOTFILES_DIR/configs/shell"
    echo "zshrc content" > "$DOTFILES_DIR/configs/shell/dot-zshrc"
    ln -s "$DOTFILES_DIR/configs/shell/dot-zshrc" "$TEST_HOME/.zshrc"

    # Commit the changes to avoid warnings
    cd "$DOTFILES_DIR"
    git add configs/
    git commit -m "Add test configs" --quiet
    cd - >/dev/null

    local output
    local exit_code=0
    output=$(run_health_check) || exit_code=$?

    assert_contains "$output" "Status: HEALTHY" "System is healthy"
    assert_contains "$output" "Current system links: 2" "Found 2 new system links"
    assert_exit_code "$exit_code" 0 "Health check passes"
}

# Test 2: Legacy system
test_legacy_system() {
    setup_test "Legacy system"

    # Create old system symlinks
    mkdir -p "$DOTFILES_DIR/emacs"
    echo "emacs config" > "$DOTFILES_DIR/emacs/init.el"
    ln -s "$DOTFILES_DIR/emacs" "$TEST_HOME/.emacs.d"

    mkdir -p "$DOTFILES_DIR/nvim"
    echo "nvim config" > "$DOTFILES_DIR/nvim/init.vim"
    ln -s "$DOTFILES_DIR/nvim" "$TEST_HOME/.nvim"

    local output
    local exit_code=0
    output=$(run_health_check) || exit_code=$?

    assert_contains "$output" "Status: LEGACY" "System detected as legacy"
    assert_contains "$output" "Legacy system links: 2" "Found 2 legacy links"
    assert_exit_code "$exit_code" 1 "Health check fails for legacy system"
}

# Test 3: Mixed system
test_mixed_system() {
    setup_test "Mixed system"

    # Create both old and new system symlinks
    mkdir -p "$DOTFILES_DIR/configs/git"
    echo "gitconfig content" > "$DOTFILES_DIR/configs/git/dot-gitconfig"
    ln -s "$DOTFILES_DIR/configs/git/dot-gitconfig" "$TEST_HOME/.gitconfig"

    mkdir -p "$DOTFILES_DIR/emacs"
    echo "emacs config" > "$DOTFILES_DIR/emacs/init.el"
    ln -s "$DOTFILES_DIR/emacs" "$TEST_HOME/.emacs.d"

    local output
    local exit_code=0
    output=$(run_health_check) || exit_code=$?

    assert_contains "$output" "Status: MIXED" "System detected as mixed"
    assert_contains "$output" "Current system links: 1" "Found 1 new system link"
    assert_contains "$output" "Legacy system links: 1" "Found 1 legacy link"
    assert_exit_code "$exit_code" 1 "Health check fails for mixed system"
}

# Test 4: Broken links
test_broken_links() {
    setup_test "System with broken links"

    # Create broken symlinks
    ln -s "/nonexistent/path" "$TEST_HOME/.gitconfig"
    ln -s "$DOTFILES_DIR/configs/missing" "$TEST_HOME/.zshrc"

    local output
    local exit_code=0
    output=$(run_health_check) || exit_code=$?


    assert_contains "$output" "Status: CRITICAL" "System has critical issues"
    assert_contains "$output" "Broken links: 2" "Found 2 broken links"
    assert_exit_code "$exit_code" 1 "Health check fails for broken links"
}

# Test 5: XDG config directory
test_xdg_config() {
    setup_test "XDG config directory"

    # Create .config directory structure
    mkdir -p "$TEST_HOME/.config/nvim"
    mkdir -p "$DOTFILES_DIR/configs/nvim/dot-config/nvim"
    echo "nvim config" > "$DOTFILES_DIR/configs/nvim/dot-config/nvim/init.lua"
    ln -s "$DOTFILES_DIR/configs/nvim/dot-config/nvim/init.lua" "$TEST_HOME/.config/nvim/init.lua"

    local output
    local exit_code=0
    output=$(run_health_check) || exit_code=$?

    assert_contains "$output" "Current system links: 1" "Found XDG config link"
    assert_exit_code "$exit_code" 0 "Health check passes with XDG configs"
}

# Test 6: Windows paths (simulated)
test_windows_paths() {
    setup_test "Windows paths"

    # Simulate Windows environment
    export TEST_PLATFORM="windows"

    # Create Windows-style paths
    mkdir -p "$TEST_HOME/AppData/Local/nvim"
    mkdir -p "$TEST_HOME/AppData/Roaming/Code"
    mkdir -p "$DOTFILES_DIR/configs/nvim_win"

    echo "nvim config" > "$DOTFILES_DIR/configs/nvim_win/init.vim"
    ln -s "$DOTFILES_DIR/configs/nvim_win/init.vim" "$TEST_HOME/AppData/Local/nvim/init.vim"

    local output
    local exit_code=0
    output=$(run_health_check) || exit_code=$?


    assert_contains "$output" "Current system links: 1" "Found Windows AppData link"

    unset TEST_PLATFORM
}

# Test 7: Empty system
test_empty_system() {
    setup_test "Empty system"

    local output
    local exit_code=0
    output=$(run_health_check) || exit_code=$?

    assert_contains "$output" "Status: EMPTY" "System detected as empty"
    assert_contains "$output" "No dotfiles configurations found" "No configs message"
    assert_exit_code "$exit_code" 1 "Health check fails for empty system"
}

# Run all tests
echo "🏃 Running dotfiles health check tests..."
echo "========================================"

test_new_system
test_legacy_system
test_mixed_system
test_broken_links
test_xdg_config
test_windows_paths
test_empty_system

# Summary
echo
echo "📊 Test Summary"
echo "==============="
echo "Tests run: $TESTS_RUN"
echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"

# Clean up
rm -rf "$TEST_ROOT"

# Exit with appropriate code
if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "\n${GREEN}✨ All tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}❌ Some tests failed${NC}"
    exit 1
fi
