#!/usr/bin/env bash
# Test Suite for P1/P2 Package Management System
# Test-Driven Development approach

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_TOOL="$SCRIPT_DIR/package-management-p1p2.sh"

# Test counter
TESTS_RUN=0
TESTS_PASSED=0

# Test utilities
assert_equals() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [ "$expected" = "$actual" ]; then
        echo "✓ PASS: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ FAIL: $test_name"
        echo "  Expected: '$expected'"
        echo "  Actual:   '$actual'"
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local test_name="$3"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [[ "$haystack" == *"$needle"* ]]; then
        echo "✓ PASS: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ FAIL: $test_name"
        echo "  Expected '$haystack' to contain '$needle'"
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
        echo "✗ FAIL: $test_name"
        echo "  File does not exist: '$file'"
    fi
}

# Test: Package file structure exists
test_package_files_exist() {
    echo "=== Testing Package File Structure ==="
    
    # Core files
    assert_file_exists "$SCRIPT_DIR/data/osx-basic-core-brew.txt" "OSX basic core file exists"
    assert_file_exists "$SCRIPT_DIR/data/arch-basic-core-pacman.txt" "Arch basic core file exists"
    assert_file_exists "$SCRIPT_DIR/data/ubuntu-basic-core-apt.txt" "Ubuntu basic core file exists"
    
    # P1 editors
    assert_file_exists "$SCRIPT_DIR/data/osx-p1-cli-editors-brew.txt" "OSX P1 CLI editors file exists"
    assert_file_exists "$SCRIPT_DIR/data/arch-p1-cli-editors-pacman.txt" "Arch P1 CLI editors file exists"
    assert_file_exists "$SCRIPT_DIR/data/ubuntu-p1-cli-editors-apt.txt" "Ubuntu P1 CLI editors file exists"
    
    # P1 dev env
    assert_file_exists "$SCRIPT_DIR/data/osx-p1-dev-env-brew.txt" "OSX P1 dev env file exists"
    assert_file_exists "$SCRIPT_DIR/data/arch-p1-dev-env-pacman.txt" "Arch P1 dev env file exists"
    assert_file_exists "$SCRIPT_DIR/data/ubuntu-p1-dev-env-apt.txt" "Ubuntu P1 dev env file exists"
}

# Test: Show config with no categories enabled
test_show_config_minimal() {
    echo "=== Testing Show Config - Minimal ==="
    
    local output
    output=$(DOTFILES_PLATFORM=arch \
             DOTFILES_CLI_EDITORS=false \
             DOTFILES_DEV_ENV=false \
             DOTFILES_CLI_UTILS=false \
             DOTFILES_GUI_APPS=false \
             "$PACKAGE_TOOL" show-config 2>/dev/null || true)
    
    assert_contains "$output" "Platform: arch" "Platform shown correctly"
    assert_contains "$output" "✓ basic-core" "Basic core always enabled"
    assert_contains "$output" "✗ CLI_EDITORS" "CLI editors disabled"
    assert_contains "$output" "✗ DEV_ENV" "Dev env disabled"
}

# Test: Show config with P1 categories enabled
test_show_config_p1_enabled() {
    echo "=== Testing Show Config - P1 Enabled ==="
    
    local output
    output=$(DOTFILES_PLATFORM=osx \
             DOTFILES_CLI_EDITORS=true \
             DOTFILES_DEV_ENV=true \
             DOTFILES_CLI_UTILS=true \
             DOTFILES_GUI_APPS=false \
             "$PACKAGE_TOOL" show-config 2>/dev/null || true)
    
    assert_contains "$output" "Platform: osx" "Platform shown correctly"
    assert_contains "$output" "✓ CLI_EDITORS" "CLI editors enabled"
    assert_contains "$output" "✓ DEV_ENV" "Dev env enabled"
    assert_contains "$output" "✓ CLI_UTILS" "CLI utils enabled"
    assert_contains "$output" "✗ GUI_APPS" "GUI apps disabled"
}

# Test: Show config with P2 categories enabled
test_show_config_p2_enabled() {
    echo "=== Testing Show Config - P2 Enabled ==="
    
    local output
    output=$(DOTFILES_PLATFORM=ubuntu \
             DOTFILES_CLI_EDITORS=true \
             DOTFILES_DEV_ENV=true \
             DOTFILES_CLI_EDITORS_P2=true \
             DOTFILES_DEV_ENV_P2=true \
             "$PACKAGE_TOOL" show-config 2>/dev/null || true)
    
    assert_contains "$output" "✓ CLI_EDITORS" "P1 CLI editors enabled"
    assert_contains "$output" "✓ DEV_ENV" "P1 Dev env enabled"
    assert_contains "$output" "✓ CLI_EDITORS_P2" "P2 CLI editors enabled"
    assert_contains "$output" "✓ DEV_ENV_P2" "P2 Dev env enabled"
}

# Test: Error handling for missing platform
test_error_handling_missing_platform() {
    echo "=== Testing Error Handling ==="
    
    local output
    output=$(unset DOTFILES_PLATFORM; "$PACKAGE_TOOL" show-config 2>&1 || true)
    
    assert_contains "$output" "DOTFILES_PLATFORM not set" "Error message for missing platform"
}

# Test: Package file content validation
test_package_file_content() {
    echo "=== Testing Package File Content ==="
    
    # Check basic core contains essentials
    local core_content
    core_content=$(cat "$SCRIPT_DIR/data/arch-basic-core-pacman.txt")
    assert_contains "$core_content" "git" "Core contains git"
    assert_contains "$core_content" "stow" "Core contains stow"
    assert_contains "$core_content" "vim" "Core contains vim fallback"
    
    # Check P1 editors contains configured editors
    local editors_content
    editors_content=$(cat "$SCRIPT_DIR/data/osx-p1-cli-editors-brew.txt")
    assert_contains "$editors_content" "neovim" "P1 editors contains neovim"
    assert_contains "$editors_content" "emacs-plus" "P1 editors contains emacs"
}

# Test: Package manager categorization
test_package_manager_categorization() {
    echo "=== Testing Package Manager Categorization ==="
    
    # OSX should use brew primarily
    assert_file_exists "$SCRIPT_DIR/data/osx-p1-cli-editors-brew.txt" "OSX uses brew for editors"
    assert_file_exists "$SCRIPT_DIR/data/osx-p1-gui-apps-cask.txt" "OSX uses cask for GUI apps"
    
    # Arch should use pacman + AUR
    assert_file_exists "$SCRIPT_DIR/data/arch-p1-cli-editors-pacman.txt" "Arch uses pacman for editors"
    assert_file_exists "$SCRIPT_DIR/data/arch-p1-cli-editors-aur.txt" "Arch uses AUR for specialized packages"
    
    # Ubuntu should use apt + selective brew
    assert_file_exists "$SCRIPT_DIR/data/ubuntu-p1-cli-editors-apt.txt" "Ubuntu uses apt for editors"
    assert_file_exists "$SCRIPT_DIR/data/ubuntu-p2-cli-editors-brew.txt" "Ubuntu uses brew for newer packages"
}

# Test: Platform-specific package choices
test_platform_specific_choices() {
    echo "=== Testing Platform-Specific Choices ==="
    
    # OSX emacs choice
    local osx_editors
    osx_editors=$(cat "$SCRIPT_DIR/data/osx-p1-cli-editors-brew.txt")
    assert_contains "$osx_editors" "emacs-plus@31" "OSX uses emacs-plus tap"
    
    # Arch emacs choice  
    local arch_editors_aur
    arch_editors_aur=$(cat "$SCRIPT_DIR/data/arch-p1-cli-editors-aur.txt")
    assert_contains "$arch_editors_aur" "emacs-plus" "Arch uses emacs-plus from AUR"
    
    # Ubuntu emacs choice
    local ubuntu_editors
    ubuntu_editors=$(cat "$SCRIPT_DIR/data/ubuntu-p1-cli-editors-apt.txt")
    assert_contains "$ubuntu_editors" "emacs" "Ubuntu uses system emacs package"
}

# Main test runner
run_all_tests() {
    echo "🧪 Running P1/P2 Package Management Test Suite"
    echo "=============================================="
    
    test_package_files_exist
    test_show_config_minimal
    test_show_config_p1_enabled
    test_show_config_p2_enabled
    test_error_handling_missing_platform
    test_package_file_content
    test_package_manager_categorization
    test_platform_specific_choices
    
    echo ""
    echo "=============================================="
    echo "📊 Test Results: $TESTS_PASSED/$TESTS_RUN tests passed"
    
    if [ $TESTS_PASSED -eq $TESTS_RUN ]; then
        echo "🎉 All tests passed!"
        exit 0
    else
        echo "❌ Some tests failed!"
        exit 1
    fi
}

# Run tests if script called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_all_tests
fi