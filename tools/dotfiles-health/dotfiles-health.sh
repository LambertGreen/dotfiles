#!/usr/bin/env bash

# Dotfiles Health Check Tool
# A comprehensive tool for validating and maintaining dotfiles symlink health
#
# Usage:
#   source dotfiles-health.sh
#   dotfiles_health_check [--verbose] [--log <file>]
#   dotfiles_cleanup_broken_links [--remove]

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

# Use environment variables if set (for testing), otherwise use defaults
if [[ -n "${DOTFILES_DIR:-}" ]]; then
    DOTFILES_DIR="${DOTFILES_DIR}"
else
    # Find dotfiles directory based on script location
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
    DOTFILES_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

# Use TEST_HOME if set (for testing), otherwise use actual HOME
TEST_HOME="${TEST_HOME:-$HOME}"

OLD_SYSTEM_PACKAGES=(emacs hammerspoon nvim alfred-settings autohotkey nvim_win)

# =============================================================================
# SHARED SYMLINK DETECTION
# =============================================================================

# Check if a single symlink is broken
# Usage: _is_symlink_broken "/path/to/symlink"
# Returns: 0 if broken, 1 if valid
_is_symlink_broken() {
    local link="$1"
    local target=$(readlink "$link" 2>/dev/null || true)

    # Test target existence from the symlink's directory context (handles relative paths)
    local link_dir=$(dirname "$link")
    if [[ -z "$target" ]] || ! (cd "$link_dir" && test -e "$target"); then
        return 0  # Broken
    else
        return 1  # Valid
    fi
}

# Find broken symlinks that point to dotfiles directory
# Usage: _find_broken_symlinks
# Sets: FOUND_BROKEN_SYMLINKS array with broken symlink paths
# Get standard dotfile search directories
# Returns: array of directories to search for symlinks
_get_search_directories() {
    local dirs=()
    dirs+=("$TEST_HOME")  # Home directory (depth 1 only)
    [[ -d "$TEST_HOME/.config" ]] && dirs+=("$TEST_HOME/.config")
    [[ -d "$TEST_HOME/.local/share/applications" ]] && dirs+=("$TEST_HOME/.local/share/applications")
    
    # Common dotfile directories
    local dotfile_dirs=("$TEST_HOME/.hammerspoon" "$TEST_HOME/.tmux" "$TEST_HOME/.gnupg" "$TEST_HOME/.spacemacs.d" "$TEST_HOME/.doom.d")
    if [[ "$OSTYPE" == "darwin"* ]]; then
        dotfile_dirs+=("$TEST_HOME/Library/Application Support/Code/User" "$TEST_HOME/Library/Application Support/Cursor/User" "$TEST_HOME/Library/Keybindings")
    elif [[ -d "$TEST_HOME/AppData" ]]; then
        dotfile_dirs+=("$TEST_HOME/AppData/Local" "$TEST_HOME/AppData/Roaming")
    fi
    
    for dir in "${dotfile_dirs[@]}"; do
        [[ -d "$dir" ]] && dirs+=("$dir")
    done
    
    printf '%s\n' "${dirs[@]}"
}

# Core function to find broken symlinks in dotfile locations
# Args: filter_dotfiles_only (true/false) - if true, only include symlinks pointing to dotfiles repo
# Sets FOUND_BROKEN_SYMLINKS array with results
_find_broken_symlinks() {
    local filter_dotfiles_only="${1:-false}"
    FOUND_BROKEN_SYMLINKS=()
    
    # Get search directories using shared function
    local search_dirs=()
    while IFS= read -r dir; do
        search_dirs+=("$dir")
    done < <(_get_search_directories)
    
    # Find broken symlinks using find (fd doesn't handle broken symlinks well)
    for dir in "${search_dirs[@]}"; do
        local depth_args=""
        [[ "$dir" == "$TEST_HOME" ]] && depth_args="-maxdepth 1"
        
        # Exclude Temp directory on Windows
        local exclude_args=""
        if [[ "$dir" == *"AppData/Local"* ]]; then
            exclude_args="-path '*/Temp/*' -prune -o"
        fi
        
        while IFS= read -r link; do
            if [[ "$filter_dotfiles_only" == "true" ]]; then
                _check_dotfile_symlink "$link" && FOUND_BROKEN_SYMLINKS+=("$link")
            else
                FOUND_BROKEN_SYMLINKS+=("$link")
            fi
        done < <(eval "find \"$dir\" $depth_args $exclude_args -type l -exec test ! -e {} \; -print" 2>/dev/null)
    done
}

# Helper function to check if broken symlink points to dotfiles directory
_check_dotfile_symlink() {
    local link="$1"
    local target=$(readlink "$link" 2>/dev/null || true)

    # Check if target contains the actual dotfiles directory path
    if [[ "$target" == *"$DOTFILES_DIR"* ]]; then
        return 0
    fi

    # For relative paths, resolve from the link's directory
    local link_dir=$(dirname "$link")
    local resolved_target=""
    if [[ -n "$target" ]]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS realpath doesn't support -m flag
            resolved_target=$(cd "$link_dir" 2>/dev/null && realpath "$target" 2>/dev/null || echo "")
        else
            # Linux realpath supports -m for missing paths
            resolved_target=$(cd "$link_dir" 2>/dev/null && realpath -m "$target" 2>/dev/null || echo "")
        fi
    fi

    if [[ -n "$resolved_target" ]] && [[ "$resolved_target" == *"$DOTFILES_DIR"* ]]; then
        return 0
    fi

    # Also check for common dotfiles directory patterns
    [[ "$target" == *"/dotfiles/"* ]] || [[ "$target" == *"/.dotfiles/"* ]] || [[ "$target" == *"dotfiles/"* ]]
}

# Categorize symlinks by type (new system, legacy, broken)
# Sets: NEW_LINKS, OLD_LINKS, BROKEN_LINKS, WARNINGS, ERRORS arrays

# Categorize symlinks by type (new system, legacy, broken)
# Sets: NEW_LINKS, OLD_LINKS, BROKEN_LINKS, WARNINGS, ERRORS arrays
_categorize_symlinks() {
    # Initialize arrays
    NEW_LINKS=()
    OLD_LINKS=()
    BROKEN_LINKS=()
    WARNINGS=()
    ERRORS=()
    
    # First, find all broken symlinks using the shared function (no filtering)
    _find_broken_symlinks false
    BROKEN_LINKS=("${FOUND_BROKEN_SYMLINKS[@]}")
    for link in "${BROKEN_LINKS[@]}"; do
        ERRORS+=("Broken symlink: $link")
    done
    
    # Now categorize non-broken symlinks that point to dotfiles
    # Use same search locations as _find_broken_symlinks for consistency
    local search_dirs=()
    while IFS= read -r dir; do
        search_dirs+=("$dir")
    done < <(_get_search_directories)
    
    # Find all non-broken symlinks that point to dotfiles
    if command -v fd >/dev/null 2>&1; then
        for dir in "${search_dirs[@]}"; do
            local depth_args=""
            [[ "$dir" == "$TEST_HOME" ]] && depth_args="--max-depth 1"
            
            while IFS= read -r link; do
                # Skip if broken (already handled)
                local is_broken=false
                for broken in "${BROKEN_LINKS[@]}"; do
                    [[ "$link" == "$broken" ]] && is_broken=true && break
                done
                [[ "$is_broken" == "true" ]] && continue
                
                # Only process symlinks that point to dotfiles
                if [[ -L "$link" ]] && [[ -e "$link" ]] && _check_dotfile_symlink "$link"; then
                    local target=$(readlink "$link" 2>/dev/null || continue)
                    local display_link="$link"
                    
                    # Make display path relative to home if possible
                    [[ "$link" == "$TEST_HOME/"* ]] && display_link="${link#$TEST_HOME/}"
                    
                    if [[ "$target" == *"/configs/"* ]]; then
                        # New system link
                        NEW_LINKS+=("$display_link -> $target")
                    else
                        # Check if it's an old system package
                        local is_old=false
                        for pkg in "${OLD_SYSTEM_PACKAGES[@]}"; do
                            if [[ "$target" == *"/$pkg"* ]]; then
                                OLD_LINKS+=("$display_link -> $target")
                                WARNINGS+=("Legacy symlink detected: $display_link -> $target")
                                is_old=true
                                break
                            fi
                        done
                        if [[ "$is_old" == "false" ]]; then
                            NEW_LINKS+=("$display_link -> $target")
                        fi
                    fi
                fi
            done < <(fd --type symlink $depth_args . "$dir" 2>/dev/null)
        done
    else
        # Fallback to find (same logic as fd version)
        for dir in "${search_dirs[@]}"; do
            local depth_args=""
            [[ "$dir" == "$TEST_HOME" ]] && depth_args="-maxdepth 1"
            
            # Exclude Temp directory on Windows
            local exclude_args=""
            if [[ "$dir" == *"AppData/Local"* ]]; then
                exclude_args="-path '*/Temp/*' -prune -o"
            fi
            
            while IFS= read -r link; do
                # Skip if broken (already handled)
                local is_broken=false
                for broken in "${BROKEN_LINKS[@]}"; do
                    [[ "$link" == "$broken" ]] && is_broken=true && break
                done
                [[ "$is_broken" == "true" ]] && continue
                
                # Only process symlinks that point to dotfiles
                if [[ -L "$link" ]] && [[ -e "$link" ]] && _check_dotfile_symlink "$link"; then
                    local target=$(readlink "$link" 2>/dev/null || continue)
                    local display_link="$link"
                    
                    # Make display path relative to home if possible
                    [[ "$link" == "$TEST_HOME/"* ]] && display_link="${link#$TEST_HOME/}"
                    
                    if [[ "$target" == *"/configs/"* ]]; then
                        # New system link
                        NEW_LINKS+=("$display_link -> $target")
                    else
                        # Check if it's an old system package
                        local is_old=false
                        for pkg in "${OLD_SYSTEM_PACKAGES[@]}"; do
                            if [[ "$target" == *"/$pkg"* ]]; then
                                OLD_LINKS+=("$display_link -> $target")
                                WARNINGS+=("Legacy symlink detected: $display_link -> $target")
                                is_old=true
                                break
                            fi
                        done
                        if [[ "$is_old" == "false" ]]; then
                            NEW_LINKS+=("$display_link -> $target")
                        fi
                    fi
                fi
            done < <(eval "find \"$dir\" $depth_args $exclude_args -type l -print" 2>/dev/null)
        done
    fi
}


# =============================================================================
# PACKAGE HEALTH CHECKS
# =============================================================================

# Check package health using TOML definitions
# Usage: _check_package_health log_output
_check_package_health() {
    local log_output="$1"

    $log_output "🔧 Package Health Checks"

    local package_data_dir="$DOTFILES_DIR/tools/package-management/package-definitions"
    local toml_parser="$DOTFILES_DIR/tools/package-management/scripts/toml-parser.py"

    # Check if we have the infrastructure for TOML-based health checks
    if [ ! -d "$package_data_dir" ]; then
        $log_output "  • ⚠️  Package data directory not found: $package_data_dir"
        WARNINGS+=("Package data directory not found")
        $log_output
        return
    fi

    if [ ! -f "$toml_parser" ]; then
        $log_output "  • ⚠️  TOML parser not found: $toml_parser"
        WARNINGS+=("TOML parser not found")
        $log_output
        return
    fi

    if ! command -v python3 >/dev/null 2>&1; then
        $log_output "  • ⚠️  Python3 not available for TOML parsing"
        WARNINGS+=("Python3 not available for TOML parsing")
        $log_output
        return
    fi

    # Determine platform for health checks
    local platform="${DOTFILES_PLATFORM:-osx}"

    # Find TOML files and run health checks
    local checked_packages=0
    local failed_packages=0

    # Arrays to track passed and failed packages for verbose output
    PACKAGE_PASSED=()
    PACKAGE_FAILED=()

    # Track packages we've already checked to avoid duplicates
    CHECKED_PACKAGES=()

    # Cache brew package lists for fast lookups (if brew is available)
    BREW_PACKAGES=""
    BREW_CASKS=""
    if command -v brew >/dev/null 2>&1; then
        $log_output "  • Caching brew package lists for fast lookups..."
        BREW_PACKAGES=$(brew list 2>/dev/null || echo "")
        BREW_CASKS=$(brew list --cask 2>/dev/null || echo "")
    fi

    # Define which categories to check based on configuration
    local categories_to_check=()

    # Check P1 categories if enabled
    if [ "${DOTFILES_CLI_EDITORS:-false}" = "true" ]; then
        categories_to_check+=("cli-editors:p1")
    fi

    if [ "${DOTFILES_DEV_ENV:-false}" = "true" ]; then
        categories_to_check+=("dev-env:p1")
    fi

    if [ "${DOTFILES_CLI_UTILS:-false}" = "true" ]; then
        categories_to_check+=("cli-utils:p1")
    fi

    if [ "${DOTFILES_GUI_APPS:-false}" = "true" ]; then
        categories_to_check+=("gui-apps:p1")
    fi

    # Check P2 categories if explicitly enabled
    if [ "${DOTFILES_CLI_EDITORS_HEAVY:-false}" = "true" ]; then
        categories_to_check+=("cli-editors:p2")
    fi

    if [ "${DOTFILES_DEV_ENV_HEAVY:-false}" = "true" ]; then
        categories_to_check+=("dev-env:p2")
    fi

    if [ "${DOTFILES_CLI_UTILS_HEAVY:-false}" = "true" ]; then
        categories_to_check+=("cli-utils:p2")
    fi

    if [ "${DOTFILES_GUI_APPS_HEAVY:-false}" = "true" ]; then
        categories_to_check+=("gui-apps:p2")
    fi

    # Process only enabled categories
    if [ ${#categories_to_check[@]} -eq 0 ]; then
        $log_output "  • ℹ️  No package categories enabled in configuration"
        $log_output
        return
    fi

    for category_priority in "${categories_to_check[@]}"; do
        local category="${category_priority%:*}"
        local priority="${category_priority#*:}"
        local toml_file="$package_data_dir/$category.toml"

        if [ ! -f "$toml_file" ]; then
            continue
        fi

        $log_output "  • Checking $category packages ($priority priority)..."

        # Get health checks from TOML for specific priority
        local health_checks
        local python_cmd="python3"
        # Use MINGW64 Python on MSYS2 for better package support
        if [[ "$(uname -s)" == *"_NT"* ]] && [[ -x "/mingw64/bin/python3" ]]; then
            python_cmd="/mingw64/bin/python3"
        fi
        health_checks=$($python_cmd "$toml_parser" "$toml_file" --action health-checks --platform "$platform" --priority "$priority" --format bash 2>/dev/null)

        if [ -n "$health_checks" ]; then
            # Temporarily disable strict mode for eval of dynamic commands
            set +e
            while IFS= read -r check_cmd; do
                if [ -n "$check_cmd" ]; then
                    eval "$check_cmd"
                fi
            done <<< "$health_checks"
            set -e
        fi
    done

    if [ $checked_packages -gt 0 ]; then
        if [ $failed_packages -eq 0 ]; then
            $log_output "  • ✅ All $checked_packages packages healthy"
        else
            $log_output "  • ⚠️  $failed_packages of $checked_packages packages failed health checks"
        fi
    else
        $log_output "  • ℹ️  No TOML packages configured for health checking"
    fi

    $log_output
}

# Fast brew package check using cached lists
check_brew_package() {
    local package_name="$1"
    local package_type="$2"  # "formula" or "cask"

    if [[ "$package_type" == "cask" ]]; then
        echo "$BREW_CASKS" | grep -q "^${package_name}$"
    else
        echo "$BREW_PACKAGES" | grep -q "^${package_name}$"
    fi
}

# Windows package manager checks
check_scoop_package() {
    local package_name="$1"
    if command -v scoop >/dev/null 2>&1; then
        scoop list | grep -q "^${package_name} "
    else
        return 1
    fi
}

check_choco_package() {
    local package_name="$1"
    if command -v choco >/dev/null 2>&1; then
        choco list --local-only | grep -q "^${package_name} "
    else
        return 1
    fi
}

check_winget_package() {
    local package_name="$1"
    if command -v winget >/dev/null 2>&1; then
        winget list --name "$package_name" >/dev/null 2>&1
    else
        return 1
    fi
}

# Helper function called by TOML parser for each package check
check_package() {
    local name="$1"
    local executable="$2"
    local health_check="$3"

    # Skip if we've already checked this package
    local already_checked=false
    if [[ ${#CHECKED_PACKAGES[@]} -gt 0 ]]; then
        for checked_pkg in "${CHECKED_PACKAGES[@]}"; do
            if [[ "$checked_pkg" == "$name" ]]; then
                already_checked=true
                break
            fi
        done
    fi

    if [[ "$already_checked" == "true" ]]; then
        return 0
    fi

    # Mark this package as checked
    CHECKED_PACKAGES+=("$name")

    # Use local variables to avoid issues with strict mode
    local current_count=$((checked_packages + 1))
    checked_packages=$current_count

    # For brew packages, try fast brew check first
    if [[ "$health_check" == *"brew-check"* ]]; then
        # Extract package type and name from health check
        local brew_type=$(echo "$health_check" | sed 's/.*brew-check:\([^:]*\):.*/\1/')
        local brew_name=$(echo "$health_check" | sed 's/.*brew-check:[^:]*:\(.*\)/\1/')

        if check_brew_package "$brew_name" "$brew_type"; then
            PACKAGE_PASSED+=("$name")
            return 0
        else
            local current_failed=$((failed_packages + 1))
            failed_packages=$current_failed
            WARNINGS+=("Package $name: not installed via brew")
            PACKAGE_FAILED+=("$name (not installed via brew)")
            return 1
        fi
    fi

    # For Windows package managers, check scoop/choco/winget
    if [[ "$health_check" == *"scoop-check"* ]]; then
        local scoop_name=$(echo "$health_check" | sed 's/.*scoop-check:\(.*\)/\1/')
        if check_scoop_package "$scoop_name"; then
            PACKAGE_PASSED+=("$name")
            return 0
        else
            local current_failed=$((failed_packages + 1))
            failed_packages=$current_failed
            WARNINGS+=("Package $name: not installed via scoop")
            PACKAGE_FAILED+=("$name (not installed via scoop)")
            return 1
        fi
    fi

    if [[ "$health_check" == *"choco-check"* ]]; then
        local choco_name=$(echo "$health_check" | sed 's/.*choco-check:\(.*\)/\1/')
        if check_choco_package "$choco_name"; then
            PACKAGE_PASSED+=("$name")
            return 0
        else
            local current_failed=$((failed_packages + 1))
            failed_packages=$current_failed
            WARNINGS+=("Package $name: not installed via chocolatey")
            PACKAGE_FAILED+=("$name (not installed via chocolatey)")
            return 1
        fi
    fi

    # First check if executable exists
    if ! command -v "$executable" >/dev/null 2>&1; then
        local current_failed=$((failed_packages + 1))
        failed_packages=$current_failed
        WARNINGS+=("Package $name: executable '$executable' not found")
        PACKAGE_FAILED+=("$name (executable '$executable' not found)")
        return 1
    fi

    # Run the health check command with error handling
    if eval "$health_check" >/dev/null 2>&1; then
        PACKAGE_PASSED+=("$name")
        return 0
    else
        local current_failed=$((failed_packages + 1))
        failed_packages=$current_failed
        WARNINGS+=("Package $name: health check failed - $health_check")
        PACKAGE_FAILED+=("$name (health check failed: $health_check)")
        return 1
    fi
}

# =============================================================================
# HEALTH CHECK FUNCTIONS
# =============================================================================

# Main health check function
# Usage: dotfiles_check_health [--verbose] [--log <file>]
dotfiles_check_health() {
    local VERBOSE=false
    local LOG_FILE=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --log)
                LOG_FILE="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            *)
                echo "Unknown option: $1"
                echo "Usage: dotfiles_check_health [--log <file>] [-v|--verbose]"
                return 1
                ;;
        esac
    done

    # Logging function
    log_output() {
        echo "$@"
        if [[ -n "$LOG_FILE" ]]; then
            echo "$@" >> "$LOG_FILE"
        fi
    }

    # If logging, add header with timestamp
    if [[ -n "$LOG_FILE" ]]; then
        {
            echo "========================================"
            echo "Dotfiles Health Check Log"
            echo "Date: $(date)"
            echo "========================================"
            echo
        } > "$LOG_FILE"
    fi

    log_output "🏥 Dotfiles Health Check"
    log_output "========================"
    log_output

    _check_git_status log_output
    _check_stow_availability log_output
    _check_package_health log_output

    log_output "🔍 Checking symlinks..."
    _categorize_symlinks
    log_output "🔍 Found ${#BROKEN_LINKS[@]} broken symlinks"

    # Generate health status
    log_output
    log_output "📊 Health Check Summary"
    log_output "======================"

    local HEALTH_STATUS="HEALTHY"
    local HEALTH_MESSAGE=""

    if [[ ${#ERRORS[@]} -gt 0 ]]; then
        HEALTH_STATUS="CRITICAL"
        HEALTH_MESSAGE="System has critical issues that need attention"
    elif [[ ${#OLD_LINKS[@]} -gt 0 ]] && [[ ${#NEW_LINKS[@]} -gt 0 ]]; then
        HEALTH_STATUS="MIXED"
        HEALTH_MESSAGE="System is in a mixed state (partial migration)"
    elif [[ ${#OLD_LINKS[@]} -gt 0 ]] && [[ ${#NEW_LINKS[@]} -eq 0 ]]; then
        HEALTH_STATUS="LEGACY"
        HEALTH_MESSAGE="System is using legacy configuration structure"
    elif [[ ${#WARNINGS[@]} -gt 0 ]]; then
        HEALTH_STATUS="WARNING"
        HEALTH_MESSAGE="System is functional but has warnings"
    elif [[ ${#NEW_LINKS[@]} -lt 5 ]]; then
        HEALTH_STATUS="EMPTY"
        HEALTH_MESSAGE="Few dotfiles configurations found - system needs stowing"
    else
        HEALTH_MESSAGE="All systems operational"
    fi

    # Display status with appropriate emoji
    case $HEALTH_STATUS in
        "HEALTHY")
            log_output "💚 Status: $HEALTH_STATUS - $HEALTH_MESSAGE"
            ;;
        "WARNING")
            log_output "💛 Status: $HEALTH_STATUS - $HEALTH_MESSAGE"
            ;;
        "LEGACY"|"MIXED"|"EMPTY")
            log_output "🟠 Status: $HEALTH_STATUS - $HEALTH_MESSAGE"
            ;;
        "CRITICAL")
            log_output "🔴 Status: $HEALTH_STATUS - $HEALTH_MESSAGE"
            ;;
    esac

    # Display detailed findings
    if [[ ${#ERRORS[@]} -gt 0 ]]; then
        log_output
        log_output "❌ Errors (${#ERRORS[@]}):"
        # Sort errors for consistency
        while IFS= read -r error; do
            log_output "  • $error"
        done < <(printf '%s\n' "${ERRORS[@]}" | sort)
    fi

    if [[ ${#WARNINGS[@]} -gt 0 ]]; then
        log_output
        log_output "⚠️  Warnings (${#WARNINGS[@]}):"
        # Sort warnings for consistency
        while IFS= read -r warning; do
            log_output "  • $warning"
        done < <(printf '%s\n' "${WARNINGS[@]}" | sort)
    fi

    log_output
    log_output "📈 Configuration Statistics"
    log_output "  • Current system links: ${#NEW_LINKS[@]}"
    log_output "  • Legacy system links: ${#OLD_LINKS[@]}"
    log_output "  • Broken links: ${#BROKEN_LINKS[@]}"

    # Provide recommendations
    if [[ "$HEALTH_STATUS" != "HEALTHY" ]]; then
        log_output
        log_output "💡 Recommendations:"

        case $HEALTH_STATUS in
            "LEGACY")
                log_output "  • Run migration to update to new configuration structure"
                local platform="${DOTFILES_PLATFORM:-osx}"
                log_output "  • Use: just stow $platform stow-basic-force"
                ;;
            "MIXED")
                log_output "  • Complete migration to resolve mixed state"
                log_output "  • Check which packages need updating"
                ;;
            "EMPTY")
                log_output "  • Run initial setup to configure dotfiles"
                log_output "  • Use: just stow"
                ;;
            "CRITICAL")
                log_output "  • Fix broken symlinks and critical errors first"
                log_output "  • Use: just cleanup-broken-links-remove"
                ;;
        esac
    fi

    # Verbose mode - show detailed package results and links if requested
    if [[ "$VERBOSE" == "true" ]]; then
        # Show package health details (sorted alphabetically)
        if [[ ${#PACKAGE_PASSED[@]} -gt 0 ]]; then
            log_output
            log_output "✅ Packages Passed (${#PACKAGE_PASSED[@]}):"
            # Sort alphabetically to make duplicates easier to spot
            while IFS= read -r package; do
                log_output "  • $package"
            done < <(printf '%s\n' "${PACKAGE_PASSED[@]}" | sort)
        fi

        if [[ ${#PACKAGE_FAILED[@]} -gt 0 ]]; then
            log_output
            log_output "❌ Packages Failed (${#PACKAGE_FAILED[@]}):"
            # Sort alphabetically to make duplicates easier to spot
            while IFS= read -r package; do
                log_output "  • $package"
            done < <(printf '%s\n' "${PACKAGE_FAILED[@]}" | sort)
        fi

        # Show symlink details
        if [[ ${#OLD_LINKS[@]} -gt 0 ]]; then
            log_output
            log_output "📋 Legacy Links:"
            # Sort alphabetically for consistency
            while IFS= read -r link; do
                log_output "  $link"
            done < <(printf '%s\n' "${OLD_LINKS[@]}" | sort)
        fi

        if [[ ${#NEW_LINKS[@]} -gt 0 ]]; then
            log_output
            log_output "📋 Current System Links:"
            # Sort alphabetically for consistency
            while IFS= read -r link; do
                log_output "  $link"
            done < <(printf '%s\n' "${NEW_LINKS[@]}" | sort)
        fi
    fi

    # Show log file location at the end for easy access
    if [[ -n "$LOG_FILE" ]]; then
        log_output
        log_output "📄 Full log saved to: $LOG_FILE"
    fi

    # Return appropriate exit code
    case $HEALTH_STATUS in
        "HEALTHY"|"WARNING"|"EMPTY")
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

_check_git_status() {
    local log_output="$1"

    if [[ -d "$DOTFILES_DIR/.git" ]]; then
        cd "$DOTFILES_DIR"
        local branch=$(git branch --show-current 2>/dev/null || echo "unknown")
        local git_status=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')

        $log_output "📍 Repository Information"
        $log_output "  • Directory: $DOTFILES_DIR"
        $log_output "  • Branch: $branch"

        if [[ "$git_status" -gt 0 ]]; then
            $log_output "  • ⚠️  Uncommitted changes: $git_status files"
            WARNINGS+=("Repository has $git_status uncommitted changes")
        else
            $log_output "  • ✅ Working tree clean"
        fi

        # Check if configs directory exists
        if [[ -d "$DOTFILES_DIR/configs" ]]; then
            $log_output "  • ✅ Configs directory exists"
        else
            $log_output "  • ❌ Configs directory missing"
            ERRORS+=("Configs directory not found at $DOTFILES_DIR/configs")
        fi
    else
        if [[ -z "${TEST_MODE:-}" ]]; then
            ERRORS+=("Not a git repository: $DOTFILES_DIR")
        else
            $log_output "📍 Repository Information (Test Mode)"
            $log_output "  • Directory: $DOTFILES_DIR"
            # Still check if configs directory exists
            if [[ -d "$DOTFILES_DIR/configs" ]]; then
                $log_output "  • ✅ Configs directory exists"
            else
                $log_output "  • ❌ Configs directory missing"
                ERRORS+=("Configs directory not found at $DOTFILES_DIR/configs")
            fi
        fi
    fi
    $log_output
}

_check_stow_availability() {
    local log_output="$1"

    if command -v stow &> /dev/null; then
        $log_output "🔧 Tools"
        $log_output "  • ✅ GNU Stow: $(stow --version | head -1)"
    else
        $log_output "🔧 Tools"
        $log_output "  • ❌ GNU Stow: not found"
        ERRORS+=("GNU Stow is not installed")
    fi

    if command -v just &> /dev/null; then
        $log_output "  • ✅ Just: $(just --version)"
    else
        $log_output "  • ⚠️  Just: not found (optional but recommended)"
        WARNINGS+=("Just command runner not installed")
    fi
    $log_output
}

# =============================================================================
# CLEANUP FUNCTIONS
# =============================================================================

# Main cleanup function
# Usage: dotfiles_cleanup_broken_links [--remove]
dotfiles_cleanup_broken_links() {
    local DRY_RUN=true

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --remove)
                DRY_RUN=false
                shift
                ;;
            --help|-h)
                echo "Usage: dotfiles_cleanup_broken_links [--remove]"
                echo "  Find and optionally remove broken symlinks in home directory"
                echo "  By default runs in dry-run mode (just lists broken links)"
                echo "  Use --remove to actually delete broken symlinks"
                return 0
                ;;
            *)
                echo "Unknown option: $1"
                return 1
                ;;
        esac
    done

    echo "🔍 Finding broken symlinks..."
    echo

    # Use shared detection logic, filtering to only dotfiles-related
    _find_broken_symlinks true

    if [[ ${#FOUND_BROKEN_SYMLINKS[@]} -eq 0 ]]; then
        echo "✅ No broken symlinks found!"
        return 0
    fi

    echo "Found ${#FOUND_BROKEN_SYMLINKS[@]} broken symlinks:"
    echo

    # Display broken links (sorted for consistency)
    while IFS= read -r link; do
        target=$(readlink "$link" 2>/dev/null || echo "[unreadable]")
        echo "  ❌ $link -> $target"
    done < <(printf '%s\n' "${FOUND_BROKEN_SYMLINKS[@]}" | sort)

    echo

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "ℹ️  This was a dry run. Use 'just cleanup-broken-links-remove' to delete these broken symlinks."
    else
        echo "⚠️  Removing broken symlinks..."
        removed_count=0

        for link in "${FOUND_BROKEN_SYMLINKS[@]}"; do
            if rm "$link" 2>/dev/null; then
                echo "  ✓ Removed: $link"
                removed_count=$((removed_count + 1))
            else
                echo "  ✗ Failed to remove: $link"
            fi
        done

        echo
        echo "🧹 Removed $removed_count broken symlinks"
    fi

    return 0
}

# =============================================================================
# INITIALIZATION
# =============================================================================

# Export functions for use when sourced
export -f dotfiles_check_health
export -f dotfiles_cleanup_broken_links

# =============================================================================
# MAIN - Run when executed directly (not sourced)
# =============================================================================

# Run health check if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    dotfiles_check_health "$@"
fi
