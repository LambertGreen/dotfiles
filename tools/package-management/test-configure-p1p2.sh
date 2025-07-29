#!/usr/bin/env bash
# Test Suite for P1/P2 Configure Script
# Test-Driven Development approach

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIGURE_SCRIPT="$PROJECT_ROOT/configure-p1p2.sh"

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

# Setup test environment
setup_test_env() {
    cd "$PROJECT_ROOT"
    # Remove any existing config
    rm -f .dotfiles.env
}

cleanup_test_env() {
    cd "$PROJECT_ROOT"
    # Clean up test config
    rm -f .dotfiles.env
}

# Test: Configure script exists and is executable
test_configure_script_exists() {
    echo "=== Testing Configure Script Existence ==="
    
    assert_file_exists "$CONFIGURE_SCRIPT" "Configure script exists"
    
    # Test if executable
    if [ -x "$CONFIGURE_SCRIPT" ]; then
        echo "✓ PASS: Configure script is executable"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ FAIL: Configure script is not executable"
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
}

# Test: Developer profile configuration
test_developer_profile() {
    echo "=== Testing Developer Profile ==="
    
    setup_test_env
    
    # Simulate input: arch platform (2), profile approach (1), developer profile (2)
    local output
    output=$(echo -e "2\n1\n2" | "$CONFIGURE_SCRIPT" --no-autodetect 2>/dev/null || true)
    
    if [ -f .dotfiles.env ]; then
        local config_content
        config_content=$(cat .dotfiles.env)
        
        assert_contains "$config_content" "DOTFILES_PLATFORM=arch" "Platform set correctly"
        assert_contains "$config_content" "DOTFILES_CLI_EDITORS=true" "CLI editors enabled"
        assert_contains "$config_content" "DOTFILES_DEV_ENV=true" "Dev env enabled"
        assert_contains "$config_content" "DOTFILES_CLI_UTILS=false" "CLI utils disabled in developer profile"
        assert_contains "$config_content" "DOTFILES_GUI_APPS=false" "GUI apps disabled in developer profile"
    else
        echo "✗ FAIL: .dotfiles.env not created"
        TESTS_RUN=$((TESTS_RUN + 5))
    fi
    
    cleanup_test_env
}

# Test: Power user profile configuration
test_power_user_profile() {
    echo "=== Testing Power User Profile ==="
    
    setup_test_env
    
    # Simulate input: osx platform, profile approach, power-user profile
    local output
    output=$(echo -e "1\n1\n5" | "$CONFIGURE_SCRIPT" 2>/dev/null || true)
    
    if [ -f .dotfiles.env ]; then
        local config_content
        config_content=$(cat .dotfiles.env)
        
        assert_contains "$config_content" "DOTFILES_PLATFORM=osx" "Platform set correctly"
        assert_contains "$config_content" "DOTFILES_CLI_EDITORS=true" "CLI editors enabled"
        assert_contains "$config_content" "DOTFILES_DEV_ENV=true" "Dev env enabled"
        assert_contains "$config_content" "DOTFILES_CLI_UTILS=true" "CLI utils enabled"
        assert_contains "$config_content" "DOTFILES_GUI_APPS=true" "GUI apps enabled"
        assert_contains "$config_content" "DOTFILES_CLI_EDITORS_P2=true" "P2 CLI editors enabled"
        assert_contains "$config_content" "DOTFILES_DEV_ENV_P2=true" "P2 Dev env enabled"
    else
        echo "✗ FAIL: .dotfiles.env not created"
        TESTS_RUN=$((TESTS_RUN + 1))
    fi
    
    cleanup_test_env
}

# Test: Minimal profile configuration
test_minimal_profile() {
    echo "=== Testing Minimal Profile ==="
    
    setup_test_env
    
    # Simulate input: ubuntu platform (3), profile approach (1), minimal profile (1)
    local output
    output=$(echo -e "3\n1\n1" | "$CONFIGURE_SCRIPT" --no-autodetect 2>/dev/null || true)
    
    if [ -f .dotfiles.env ]; then
        local config_content
        config_content=$(cat .dotfiles.env)
        
        assert_contains "$config_content" "DOTFILES_PLATFORM=ubuntu" "Platform set correctly"
        assert_contains "$config_content" "DOTFILES_CLI_EDITORS=false" "CLI editors disabled"
        assert_contains "$config_content" "DOTFILES_DEV_ENV=false" "Dev env disabled"
        assert_contains "$config_content" "DOTFILES_CLI_UTILS=false" "CLI utils disabled"
        assert_contains "$config_content" "DOTFILES_GUI_APPS=false" "GUI apps disabled"
    else
        echo "✗ FAIL: .dotfiles.env not created"
        TESTS_RUN=$((TESTS_RUN + 5))
    fi
    
    cleanup_test_env
}

# Test: Custom configuration
test_custom_configuration() {
    echo "=== Testing Custom Configuration ==="
    
    setup_test_env
    
    # Simulate input: arch platform (2), custom approach (2), Y to editors, N to dev_env, Y to utils, N to gui, Y to editors_p2
    local output
    output=$(echo -e "2\n2\nY\nN\nY\nN\nY" | "$CONFIGURE_SCRIPT" --no-autodetect 2>/dev/null || true)
    
    if [ -f .dotfiles.env ]; then
        local config_content
        config_content=$(cat .dotfiles.env)
        
        assert_contains "$config_content" "DOTFILES_PLATFORM=arch" "Platform set correctly"
        assert_contains "$config_content" "DOTFILES_CLI_EDITORS=true" "CLI editors enabled"
        assert_contains "$config_content" "DOTFILES_DEV_ENV=false" "Dev env disabled"
        assert_contains "$config_content" "DOTFILES_CLI_UTILS=true" "CLI utils enabled"
        assert_contains "$config_content" "DOTFILES_GUI_APPS=false" "GUI apps disabled"
        assert_contains "$config_content" "DOTFILES_CLI_EDITORS_P2=true" "P2 CLI editors enabled"
    else
        echo "✗ FAIL: .dotfiles.env not created"
        TESTS_RUN=$((TESTS_RUN + 6))
    fi
    
    cleanup_test_env
}

# Test: Configuration file format
test_config_file_format() {
    echo "=== Testing Configuration File Format ==="
    
    setup_test_env
    
    # Generate a simple config: arch platform (2), profile approach (1), developer profile (2)
    echo -e "2\n1\n2" | "$CONFIGURE_SCRIPT" --no-autodetect 2>/dev/null || true
    
    if [ -f .dotfiles.env ]; then
        local config_content
        config_content=$(cat .dotfiles.env)
        
        assert_contains "$config_content" "# Dotfiles Configuration - P1/P2 Category System" "Header comment present"
        assert_contains "$config_content" "# Generated on" "Timestamp present"
        assert_contains "$config_content" "export DOTFILES_PLATFORM=" "Platform export present"
        
        # Check that all lines with DOTFILES_ are export statements
        local dotfiles_lines
        dotfiles_lines=$(grep "DOTFILES_" .dotfiles.env | grep -v "^#" || true)
        local all_exports=true
        while IFS= read -r line; do
            if [[ -n "$line" && ! "$line" =~ ^export ]]; then
                all_exports=false
                break
            fi
        done <<< "$dotfiles_lines"
        
        if [ "$all_exports" = true ]; then
            echo "✓ PASS: All DOTFILES variables are exported"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo "✗ FAIL: Not all DOTFILES variables are exported"
            echo "  Non-export lines: $dotfiles_lines"
        fi
        TESTS_RUN=$((TESTS_RUN + 1))
        
    else
        echo "✗ FAIL: .dotfiles.env not created"
        TESTS_RUN=$((TESTS_RUN + 4))
    fi
    
    cleanup_test_env
}

# Main test runner
run_all_tests() {
    echo "🧪 Running P1/P2 Configure Script Test Suite"
    echo "============================================="
    
    test_configure_script_exists
    test_developer_profile
    test_power_user_profile
    test_minimal_profile
    test_custom_configuration
    test_config_file_format
    
    echo ""
    echo "============================================="
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