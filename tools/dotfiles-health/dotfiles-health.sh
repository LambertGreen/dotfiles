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

# Fix Windows path case sensitivity issue with MSYS2
# MSYS2 uses lowercase /c/users but filesystem uses /c/Users
if [[ "$TEST_HOME" == "/c/users/"* ]]; then
    TEST_HOME="/c/Users${TEST_HOME#/c/users}"
fi

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
    
    # First, find broken symlinks pointing to dotfiles directory (filtered)
    _find_broken_symlinks true
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
            done < <(fd --hidden --type symlink $depth_args . "$dir" 2>/dev/null)
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

# Check if package manager is available
check_package_manager() {
    local pm="$1"
    
    case "${pm}" in
        brew)
            command -v brew >/dev/null 2>&1
            ;;
        apt)
            command -v apt >/dev/null 2>&1
            ;;
        pacman)
            command -v pacman >/dev/null 2>&1
            ;;
        pip)
            command -v pip3 >/dev/null 2>&1 || command -v pip >/dev/null 2>&1
            ;;
        npm)
            command -v npm >/dev/null 2>&1
            ;;
        gem)
            command -v gem >/dev/null 2>&1
            ;;
        cargo)
            command -v cargo >/dev/null 2>&1
            ;;
        scoop)
            command -v scoop >/dev/null 2>&1
            ;;
        choco)
            command -v choco >/dev/null 2>&1
            ;;
        winget)
            command -v winget >/dev/null 2>&1
            ;;
        snap)
            command -v snap >/dev/null 2>&1
            ;;
        *)
            return 1
            ;;
    esac
}

# Check package health using native package manager files
# Usage: _check_package_health log_output
_check_package_health() {
    local log_output="$1"

    $log_output "🔧 Package Health Checks"

    # Load machine class configuration
    local machine_class_env="${HOME}/.dotfiles.env"
    if [[ ! -f "$machine_class_env" ]]; then
        $log_output "  • ⚠️  Machine class not configured. Run: just configure"
        WARNINGS+=("Machine class not configured")
        $log_output
        return
    fi

    source "$machine_class_env"
    if [[ -z "${DOTFILES_MACHINE_CLASS:-}" ]]; then
        $log_output "  • ⚠️  DOTFILES_MACHINE_CLASS not set"
        WARNINGS+=("DOTFILES_MACHINE_CLASS not set")
        $log_output
        return
    fi

    local machine_dir="$DOTFILES_DIR/package-management/machines/$DOTFILES_MACHINE_CLASS"
    if [[ ! -d "$machine_dir" ]]; then
        $log_output "  • ⚠️  Machine class directory not found: $machine_dir"
        WARNINGS+=("Machine class directory not found")
        $log_output
        return
    fi

    $log_output "  • Machine class: $DOTFILES_MACHINE_CLASS"

    # Arrays to track passed and failed packages for verbose output
    PACKAGE_PASSED=()
    PACKAGE_FAILED=()

    local checked_packages=0
    local failed_packages=0

    # Check each package manager that has configuration
    for pm_dir in "$machine_dir"/*; do
        if [[ ! -d "$pm_dir" ]]; then
            continue
        fi

        local pm_name=$(basename "$pm_dir")
        $log_output "  • Checking $pm_name packages..."

        # Check if package manager is available
        if ! check_package_manager "$pm_name"; then
            $log_output "    - ⚠️  $pm_name not available on this system"
            WARNINGS+=("$pm_name package manager not available")
            continue
        fi

        # Check packages based on package manager type
        case "$pm_name" in
            brew)
                if [[ -f "$pm_dir/Brewfile" ]]; then
                    # Count packages in Brewfile
                    local brew_count=$(grep -c '^brew ' "$pm_dir/Brewfile" 2>/dev/null || echo 0)
                    local cask_count=$(grep -c '^cask ' "$pm_dir/Brewfile" 2>/dev/null || echo 0)
                    local total_brewfile=$((brew_count + cask_count))
                    
                    # Get system info
                    local brew_info=$(brew --version 2>/dev/null | head -n 1)
                    local installed_formulae=$(brew list --formula 2>/dev/null | wc -l | tr -d ' ')
                    local installed_casks=$(brew list --cask 2>/dev/null | wc -l | tr -d ' ')
                    
                    $log_output "    - 📊 $brew_info"
                    $log_output "    - 📦 Brewfile: $brew_count formulae, $cask_count casks ($total_brewfile total)"
                    $log_output "    - 🏠 Installed: $installed_formulae formulae, $installed_casks casks"
                    
                    # Check if packages match Brewfile
                    if brew bundle check --file="$pm_dir/Brewfile" >/dev/null 2>&1; then
                        $log_output "    - ✅ All Brewfile packages installed"
                        PACKAGE_PASSED+=("$pm_name (Brewfile)")
                    else
                        $log_output "    - ⚠️  Some Brewfile packages missing or outdated"
                        WARNINGS+=("$pm_name: Some packages missing or outdated")
                        PACKAGE_FAILED+=("$pm_name (Brewfile)")
                        failed_packages=$((failed_packages + 1))
                    fi
                    checked_packages=$((checked_packages + 1))
                fi
                ;;
                
            pip)
                if [[ -f "$pm_dir/requirements.txt" ]]; then
                    local pip_cmd="pip3"
                    command -v pip3 >/dev/null 2>&1 || pip_cmd="pip"
                    
                    # Count packages in requirements.txt
                    local req_count=$(grep -v '^#' "$pm_dir/requirements.txt" 2>/dev/null | grep -v '^$' | wc -l | tr -d ' ')
                    
                    if command -v "$pip_cmd" >/dev/null 2>&1; then
                        # Get pip info and installed packages count
                        local pip_info=$($pip_cmd --version 2>/dev/null || echo "pip version unknown")
                        local installed_count=$($pip_cmd list --user 2>/dev/null | tail -n +3 | wc -l | tr -d ' ')
                        
                        $log_output "    - 📊 $pip_info"
                        $log_output "    - 📦 requirements.txt: $req_count packages"
                        $log_output "    - 🏠 Installed (user): $installed_count packages"
                        $log_output "    - ✅ pip available for requirements.txt"
                        PACKAGE_PASSED+=("$pm_name (requirements.txt)")
                    else
                        $log_output "    - 📦 requirements.txt: $req_count packages"
                        $log_output "    - ⚠️  pip not available"
                        WARNINGS+=("$pm_name: pip not available")
                        PACKAGE_FAILED+=("$pm_name (pip not available)")
                        failed_packages=$((failed_packages + 1))
                    fi
                    checked_packages=$((checked_packages + 1))
                fi
                ;;
                
            npm)
                if [[ -f "$pm_dir/packages.txt" ]]; then
                    # Count packages in packages.txt
                    local npm_count=$(grep -v '^#' "$pm_dir/packages.txt" 2>/dev/null | grep -v '^$' | wc -l | tr -d ' ')
                    
                    if command -v npm >/dev/null 2>&1; then
                        # Get npm info and global packages count
                        local npm_info=$(npm --version 2>/dev/null | sed 's/^/npm v/' || echo "npm version unknown")
                        local node_info=$(node --version 2>/dev/null | sed 's/^/Node /' || echo "Node version unknown")
                        local installed_count=$(npm list -g --depth=0 2>/dev/null | grep -c '^├──\|^└──' || echo "0")
                        
                        $log_output "    - 📊 $npm_info, $node_info"
                        $log_output "    - 📦 packages.txt: $npm_count packages"
                        $log_output "    - 🏠 Installed (global): $installed_count packages"
                        $log_output "    - ✅ npm available for packages.txt"
                        PACKAGE_PASSED+=("$pm_name (packages.txt)")
                    else
                        $log_output "    - 📦 packages.txt: $npm_count packages"
                        $log_output "    - ⚠️  npm not available"
                        WARNINGS+=("$pm_name: npm not available")
                        PACKAGE_FAILED+=("$pm_name (npm not available)")
                        failed_packages=$((failed_packages + 1))
                    fi
                    checked_packages=$((checked_packages + 1))
                fi
                ;;
                
            apt|pacman)
                if [[ -f "$pm_dir/packages.txt" ]]; then
                    # Count packages in packages.txt
                    local pkg_count=$(grep -v '^#' "$pm_dir/packages.txt" 2>/dev/null | grep -v '^$' | wc -l | tr -d ' ')
                    
                    if command -v "$pm_name" >/dev/null 2>&1; then
                        # Get package manager info
                        local pm_info=""
                        if [[ "$pm_name" == "apt" ]]; then
                            pm_info=$(apt --version 2>/dev/null | head -1 || echo "apt version unknown")
                            local installed_count=$(dpkg -l 2>/dev/null | grep '^ii' | wc -l | tr -d ' ')
                            $log_output "    - 📊 $pm_info"
                            $log_output "    - 📦 packages.txt: $pkg_count packages"
                            $log_output "    - 🏠 Installed: $installed_count packages"
                        elif [[ "$pm_name" == "pacman" ]]; then
                            pm_info=$(pacman --version 2>/dev/null | head -1 || echo "pacman version unknown")
                            local installed_count=$(pacman -Q 2>/dev/null | wc -l | tr -d ' ')
                            $log_output "    - 📊 $pm_info"
                            $log_output "    - 📦 packages.txt: $pkg_count packages"
                            $log_output "    - 🏠 Installed: $installed_count packages"
                        fi
                        $log_output "    - ✅ $pm_name available for packages.txt"
                        PACKAGE_PASSED+=("$pm_name (packages.txt)")
                    else
                        $log_output "    - 📦 packages.txt: $pkg_count packages"
                        $log_output "    - ⚠️  $pm_name not available"
                        WARNINGS+=("$pm_name: not available")
                        PACKAGE_FAILED+=("$pm_name (not available)")
                        failed_packages=$((failed_packages + 1))
                    fi
                    checked_packages=$((checked_packages + 1))
                fi
                ;;
                
            gem)
                if [[ -f "$pm_dir/Gemfile" ]]; then
                    # Count gems in Gemfile
                    local gem_count=$(grep -c "^gem " "$pm_dir/Gemfile" 2>/dev/null || echo 0)
                    
                    if command -v gem >/dev/null 2>&1; then
                        # Get Ruby and gem info
                        local ruby_info=$(ruby --version 2>/dev/null | cut -d' ' -f1-2 || echo "Ruby version unknown")
                        local gem_info=$(gem --version 2>/dev/null | sed 's/^/RubyGems v/' || echo "RubyGems version unknown")
                        local installed_count=$(gem list 2>/dev/null | wc -l | tr -d ' ')
                        
                        $log_output "    - 📊 $ruby_info, $gem_info"
                        $log_output "    - 📦 Gemfile: $gem_count gems"
                        $log_output "    - 🏠 Installed: $installed_count gems"
                        $log_output "    - ✅ gem available for Gemfile"
                        PACKAGE_PASSED+=("$pm_name (Gemfile)")
                    else
                        $log_output "    - 📦 Gemfile: $gem_count gems"
                        $log_output "    - ⚠️  gem not available"
                        WARNINGS+=("$pm_name: gem not available")
                        PACKAGE_FAILED+=("$pm_name (gem not available)")
                        failed_packages=$((failed_packages + 1))
                    fi
                    checked_packages=$((checked_packages + 1))
                fi
                ;;
                
            *)
                $log_output "    - ℹ️  Health check not implemented for $pm_name"
                ;;
        esac
    done

    if [ $checked_packages -gt 0 ]; then
        if [ $failed_packages -eq 0 ]; then
            $log_output "  • ✅ All $checked_packages package managers healthy"
        else
            $log_output "  • ⚠️  $failed_packages of $checked_packages package managers have issues"
        fi
    else
        $log_output "  • ℹ️  No package managers configured for health checking"
    fi

    $log_output
}

# Legacy TOML-based functions removed - now using native package management

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
