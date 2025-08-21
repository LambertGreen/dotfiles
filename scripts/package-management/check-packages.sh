#!/usr/bin/env bash
# Check packages wrapper with logging

set -euo pipefail

# Set up logging
DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_DIR="${DOTFILES_ROOT}/logs"
LOG_FILE="${LOG_DIR}/check-packages-$(date +%Y%m%d-%H%M%S).log"

# Create log directory if it doesn't exist
mkdir -p "${LOG_DIR}"

# Initialize log file with header
{
    echo "Check Packages Log"
    echo "=================="
    echo "Date: $(date)"
    echo "Machine: $(hostname 2>/dev/null || echo 'unknown')"
    echo "User: ${USER:-$(whoami)}"
    echo "Script: $0 $*"
    echo "=================="
    echo ""
} > "${LOG_FILE}"

# Function to log both to console and file
log_output() {
    echo "$1" | tee -a "${LOG_FILE}"
}

# Function to log only to file (for verbose details)
log_verbose() {
    echo "$1" >> "${LOG_FILE}"
}

log_output "🔍 Checking for updates across all package managers..."
log_output ""

# Load configuration if available
if [[ -f ~/.dotfiles.env ]]; then
    source ~/.dotfiles.env
    log_verbose "Loaded configuration from ~/.dotfiles.env"
    log_verbose "DOTFILES_PLATFORM: ${DOTFILES_PLATFORM:-'not set'}"
    log_verbose "DOTFILES_MACHINE_CLASS: ${DOTFILES_MACHINE_CLASS:-'not set'}"
else
    log_verbose "No ~/.dotfiles.env found"
fi

# Track what package managers we check
checked_pms=()
updates_found=false

# Check Homebrew
if command -v brew >/dev/null 2>&1; then
    log_output "=== Homebrew ==="
    checked_pms+=("brew")

    log_verbose "Running: brew outdated"
    if outdated_brew=$(brew outdated 2>&1); then
        if [[ -n "$outdated_brew" ]]; then
            log_output "$outdated_brew"
            updates_found=true
            log_verbose "Homebrew updates available"
        else
            log_output "All Homebrew packages are up to date"
            log_verbose "No Homebrew updates"
        fi
    else
        log_output "Error checking Homebrew updates"
        log_verbose "brew outdated failed with exit code: $?"
    fi
    log_output ""
else
    log_verbose "Homebrew not available"
fi

# Check APT (Ubuntu/Debian)
if command -v apt >/dev/null 2>&1; then
    log_output "=== APT ==="
    checked_pms+=("apt")

    log_verbose "Running: sudo apt update (suppressing output)"
    if sudo apt update >/dev/null 2>&1; then
        log_verbose "apt update completed successfully"

        log_verbose "Running: apt list --upgradable"
        if upgradable_apt=$(apt list --upgradable 2>/dev/null | head -20); then
            # Remove header line and count actual packages
            # Use || true to prevent grep from causing script exit when no matches
            upgradable_count=$(echo "$upgradable_apt" | grep -v "^Listing" | wc -l | tr -d ' ' || echo "0")
            # Strip any newlines or whitespace
            upgradable_count="${upgradable_count//[$'\r\n']/}"
            if [[ ${upgradable_count:-0} -gt 0 ]]; then
                log_output "$upgradable_apt"
                updates_found=true
                log_verbose "APT updates available: $upgradable_count packages"
            else
                log_output "All APT packages are up to date"
                log_verbose "No APT updates"
            fi
        else
            log_output "Error checking APT updates"
            log_verbose "apt list --upgradable failed"
        fi
    else
        log_output "Error updating APT package list"
        log_verbose "sudo apt update failed"
    fi
    log_output ""
else
    log_verbose "APT not available"
fi

# Check pip (Python)
if command -v pip3 >/dev/null 2>&1; then
    log_output "=== Python (pip) ==="
    checked_pms+=("pip")

    log_verbose "Running: pip3 list --outdated"
    # Try user packages first, then global
    if outdated_pip=$(pip3 list --outdated --user 2>/dev/null | head -20); then
        pip_line_count=$(echo "$outdated_pip" | wc -l | tr -d ' ')
        pip_line_count="${pip_line_count//[$'\r\n']/}"
        if [[ -n "$outdated_pip" ]] && [[ ${pip_line_count:-0} -gt 2 ]]; then
            log_output "$outdated_pip"
            updates_found=true
            log_verbose "pip (user) updates available"
        else
            # Try global packages
            if outdated_pip_global=$(pip3 list --outdated 2>/dev/null | head -20); then
                pip_global_line_count=$(echo "$outdated_pip_global" | wc -l | tr -d ' ')
                pip_global_line_count="${pip_global_line_count//[$'\r\n']/}"
                if [[ -n "$outdated_pip_global" ]] && [[ ${pip_global_line_count:-0} -gt 2 ]]; then
                    log_output "$outdated_pip_global"
                    updates_found=true
                    log_verbose "pip (global) updates available"
                else
                    log_output "All pip packages are up to date"
                    log_verbose "No pip updates"
                fi
            else
                log_output "Error checking pip updates"
                log_verbose "pip3 list --outdated failed"
            fi
        fi
    else
        log_output "Error checking pip updates"
        log_verbose "pip3 list --outdated --user failed"
    fi
    log_output ""
else
    log_verbose "pip3 not available"
fi

# Check npm (Node.js)
if command -v npm >/dev/null 2>&1; then
    log_output "=== Node.js (npm) ==="
    checked_pms+=("npm")

    log_verbose "Running: npm outdated -g"
    if outdated_npm=$(npm outdated -g 2>/dev/null); then
        if [[ -n "$outdated_npm" ]]; then
            log_output "$outdated_npm"
            updates_found=true
            log_verbose "npm global updates available"
        else
            log_output "All global npm packages are up to date"
            log_verbose "No npm global updates"
        fi
    else
        log_output "Error checking npm updates"
        log_verbose "npm outdated -g failed"
    fi
    log_output ""
else
    log_verbose "npm not available"
fi

# Summary
log_output "📊 Update Check Summary"
log_output "======================="

if [[ ${#checked_pms[@]} -eq 0 ]]; then
    log_output "⚠️  No package managers found"
else
    log_output "✅ Checked package managers: ${checked_pms[*]}"

    if [[ "$updates_found" == true ]]; then
        log_output "📦 Updates available - run 'just upgrade-packages' to install"
    else
        log_output "✅ All packages are up to date"
    fi
fi

log_output ""
log_output "📝 Check packages session logged to: ${LOG_FILE}"

# Log final status to file
{
    echo ""
    echo "=== CHECK PACKAGES COMPLETION ==="
    echo "Package managers checked: ${checked_pms[*]:-none}"
    echo "Updates found: $updates_found"
    echo "DOTFILES_PLATFORM: ${DOTFILES_PLATFORM:-'not set'}"
    echo "DOTFILES_MACHINE_CLASS: ${DOTFILES_MACHINE_CLASS:-'not set'}"
    echo "=================================="
    echo ""
    echo "Check packages completed at: $(date)"
} >> "${LOG_FILE}"
