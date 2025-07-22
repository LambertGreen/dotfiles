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
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    DOTFILES_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

# Use TEST_HOME if set (for testing), otherwise use actual HOME
TEST_HOME="${TEST_HOME:-$HOME}"

OLD_SYSTEM_PACKAGES=(emacs hammerspoon nvim alfred-settings autohotkey nvim_win)
CHECK_DIRS=("$TEST_HOME")

# Add Windows paths if on Windows/MSYS2 or if TEST_PLATFORM is set
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ "${TEST_PLATFORM:-}" == "windows" ]]; then
    CHECK_DIRS+=("$TEST_HOME/AppData/Local" "$TEST_HOME/AppData/Roaming")
fi

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

# Find broken symlinks in specified directories
# Usage: _find_broken_symlinks dir1 dir2 ...
# Sets: FOUND_BROKEN_SYMLINKS array with broken symlink paths
_find_broken_symlinks() {
    local dirs=("$@")
    FOUND_BROKEN_SYMLINKS=()

    for dir in "${dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            continue
        fi

        if [[ "$dir" == *".config"* ]] || [[ "$dir" == *"AppData"* ]]; then
            # For .config and AppData, search recursively
            while IFS= read -r -d '' link; do
                if [[ -L "$link" ]] && _is_symlink_broken "$link"; then
                    FOUND_BROKEN_SYMLINKS+=("$link")
                fi
            done < <(find "$dir" -type l -print0 2>/dev/null)
        else
            # For home directory, only check depth 1 to avoid massive searches
            while IFS= read -r -d '' link; do
                if [[ -L "$link" ]] && _is_symlink_broken "$link"; then
                    FOUND_BROKEN_SYMLINKS+=("$link")
                fi
            done < <(find "$dir" -maxdepth 1 -type l -print0 2>/dev/null)
        fi
    done
}

# Categorize symlinks by type (new system, legacy, broken)
# Sets: NEW_LINKS, OLD_LINKS, BROKEN_LINKS, WARNINGS, ERRORS arrays
_categorize_symlinks() {
    local dirs=("$@")

    NEW_LINKS=()
    OLD_LINKS=()
    BROKEN_LINKS=()
    WARNINGS=()
    ERRORS=()

    for dir in "${dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            continue
        fi

        if [[ "$dir" == *"AppData"* ]]; then
            _check_symlinks_recursive "$dir"
        else
            _check_symlinks_in_dir "$dir"
        fi
    done

    # Check .config directory recursively (separate to avoid duplication)
    if [[ -d "$TEST_HOME/.config" ]]; then
        while IFS= read -r -d '' link; do
            if [[ -L "$link" ]]; then
                target=$(readlink "$link" 2>/dev/null || true)

                # Test target existence from the symlink's directory context
                link_dir=$(dirname "$link")
                if [[ -z "$target" ]] || ! (cd "$link_dir" && test -e "$target"); then
                    BROKEN_LINKS+=("$link")
                    ERRORS+=("Broken symlink: $link")
                elif [[ "$target" == *"$DOTFILES_DIR/configs/"* ]]; then
                    NEW_LINKS+=("$link → $target")
                elif [[ "$target" == *"$DOTFILES_DIR/"* ]]; then
                    OLD_LINKS+=("$link → $target")
                    WARNINGS+=("Legacy symlink detected: $link → $target")
                fi
            fi
        done < <(find "$TEST_HOME/.config" -type l -print0 2>/dev/null)
    fi
}

_check_symlinks_in_dir() {
    local dir="$1"

    if [[ ! -d "$dir" ]]; then
        return
    fi

    while IFS= read -r -d '' link; do
        if [[ -L "$link" ]]; then
            target=$(readlink "$link" 2>/dev/null || true)

            # Test target existence from the symlink's directory context
            local link_dir=$(dirname "$link")
            if [[ -z "$target" ]] || ! (cd "$link_dir" && test -e "$target"); then
                BROKEN_LINKS+=("$link")
                ERRORS+=("Broken symlink: $link")
            elif [[ "$target" == *"$DOTFILES_DIR/configs/"* ]]; then
                NEW_LINKS+=("$link → $target")
            elif [[ "$target" == *"$DOTFILES_DIR/"* ]]; then
                # Check if it's one of the old root-level packages
                for pkg in "${OLD_SYSTEM_PACKAGES[@]}"; do
                    if [[ "$target" == *"$DOTFILES_DIR/$pkg"* ]]; then
                        OLD_LINKS+=("$link → $target")
                        WARNINGS+=("Legacy symlink detected: $link → $target")
                        break
                    fi
                done
            fi
        fi
    done < <(find "$dir" -maxdepth 1 -type l -print0 2>/dev/null)
}

_check_symlinks_recursive() {
    local dir="$1"

    if [[ ! -d "$dir" ]]; then
        return
    fi

    while IFS= read -r -d '' link; do
        if [[ -L "$link" ]]; then
            target=$(readlink "$link" 2>/dev/null || true)

            # Test target existence from the symlink's directory context
            local link_dir=$(dirname "$link")
            if [[ -z "$target" ]] || ! (cd "$link_dir" && test -e "$target"); then
                BROKEN_LINKS+=("$link")
                ERRORS+=("Broken symlink: $link")
            elif [[ "$target" == *"$DOTFILES_DIR/configs/"* ]]; then
                NEW_LINKS+=("$link → $target")
            elif [[ "$target" == *"$DOTFILES_DIR/"* ]]; then
                # Check if it's one of the old root-level packages
                for pkg in "${OLD_SYSTEM_PACKAGES[@]}"; do
                    if [[ "$target" == *"$DOTFILES_DIR/$pkg"* ]]; then
                        OLD_LINKS+=("$link → $target")
                        WARNINGS+=("Legacy symlink detected: $link → $target")
                        break
                    fi
                done
            fi
        fi
    done < <(find "$dir" -type l -print0 2>/dev/null)
}

# =============================================================================
# HEALTH CHECK FUNCTIONS
# =============================================================================

# Main health check function
# Usage: dotfiles_health_check [--verbose] [--log <file>]
dotfiles_health_check() {
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
                echo "Usage: dotfiles_health_check [--log <file>] [-v|--verbose]"
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

    log_output "🔍 Checking symlinks..."
    _categorize_symlinks "${CHECK_DIRS[@]}"

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
    elif [[ ${#NEW_LINKS[@]} -eq 0 ]]; then
        HEALTH_STATUS="EMPTY"
        HEALTH_MESSAGE="No dotfiles configurations found"
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
        for error in "${ERRORS[@]}"; do
            log_output "  • $error"
        done
    fi

    if [[ ${#WARNINGS[@]} -gt 0 ]]; then
        log_output
        log_output "⚠️  Warnings (${#WARNINGS[@]}):"
        for warning in "${WARNINGS[@]}"; do
            log_output "  • $warning"
        done
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
                log_output "  • Use: just stow osx stow-basic-force"
                ;;
            "MIXED")
                log_output "  • Complete migration to resolve mixed state"
                log_output "  • Check which packages need updating"
                ;;
            "EMPTY")
                log_output "  • Run initial setup to configure dotfiles"
                log_output "  • Use: just stow osx stow-basic"
                ;;
            "CRITICAL")
                log_output "  • Fix broken symlinks and critical errors first"
                log_output "  • Use: dotfiles_cleanup_broken_links --remove"
                ;;
        esac
    fi

    # Verbose mode - show all links if requested
    if [[ "$VERBOSE" == "true" ]]; then
        if [[ ${#OLD_LINKS[@]} -gt 0 ]]; then
            log_output
            log_output "📋 Legacy Links:"
            for link in "${OLD_LINKS[@]}"; do
                log_output "  $link"
            done
        fi

        if [[ ${#NEW_LINKS[@]} -gt 0 ]]; then
            log_output
            log_output "📋 Current System Links:"
            for link in "${NEW_LINKS[@]}"; do
                log_output "  $link"
            done
        fi
    fi

    # Return appropriate exit code
    case $HEALTH_STATUS in
        "HEALTHY"|"WARNING")
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
        local status=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')

        $log_output "📍 Repository Information"
        $log_output "  • Directory: $DOTFILES_DIR"
        $log_output "  • Branch: $branch"

        if [[ "$status" -gt 0 ]]; then
            $log_output "  • ⚠️  Uncommitted changes: $status files"
            WARNINGS+=("Repository has $status uncommitted changes")
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

    # Use shared detection logic
    _find_broken_symlinks "${CHECK_DIRS[@]}"

    # Also check .config separately
    local config_dirs=()
    if [[ -d "$TEST_HOME/.config" ]]; then
        config_dirs+=("$TEST_HOME/.config")
    fi
    if [[ ${#config_dirs[@]} -gt 0 ]]; then
        local temp_broken=()
        _find_broken_symlinks "${config_dirs[@]}"
        FOUND_BROKEN_SYMLINKS+=("${FOUND_BROKEN_SYMLINKS[@]}")
    fi

    if [[ ${#FOUND_BROKEN_SYMLINKS[@]} -eq 0 ]]; then
        echo "✅ No broken symlinks found!"
        return 0
    fi

    echo "Found ${#FOUND_BROKEN_SYMLINKS[@]} broken symlinks:"
    echo

    # Display broken links
    for link in "${FOUND_BROKEN_SYMLINKS[@]}"; do
        target=$(readlink "$link" 2>/dev/null || echo "[unreadable]")
        echo "  ❌ $link -> $target"
    done

    echo

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "ℹ️  This was a dry run. Use --remove to delete these broken symlinks."
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
export -f dotfiles_health_check
export -f dotfiles_cleanup_broken_links
