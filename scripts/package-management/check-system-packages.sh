#!/usr/bin/env bash
# Check system packages - Updates registries and shows available updates
# This is the ONLY script that should update package manager registries

set -euo pipefail

# Setup
DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Configure logging
LOG_PREFIX="SYS-CHECK"
LOG_DIR="${DOTFILES_ROOT}/.logs"
LOG_FILE="${LOG_DIR}/check-system-packages-$(date +%Y%m%d-%H%M%S).log"

# Source enhanced logging utilities
source "${DOTFILES_ROOT}/scripts/package-management/shared/logging.sh"
source "${DOTFILES_ROOT}/scripts/package-management/shared/brew-lock-cleanup.sh"

# Initialize log
initialize_log "check-system-packages.sh"

# Track timing
START_TIME=$(date +%s)

# For backward compatibility with existing script
log_output() {
    log_info "$1"
}

# Function to log only to file (for verbose details)
log_verbose() {
    log_debug "$1"
}

log_section "System Package Check"
log_info "Checking system packages for updates..."

# Clean up any brew locks before starting
cleanup_brew_locks_if_needed

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

# Check Homebrew (macOS/Linux)
if command -v brew >/dev/null 2>&1; then
    log_subsection "Homebrew"
    checked_pms+=("brew")

    # UPDATE REGISTRY
    log_output "Updating Homebrew registry..."
    log_verbose "Running: brew update"
    if brew update 2>&1 | tee -a "${LOG_FILE}" >/dev/null; then
        log_verbose "brew update completed successfully"
    else
        log_output "Warning: brew update had issues"
        log_verbose "brew update failed with exit code: $?"
    fi

    # CHECK FOR UPDATES (formulas and casks with greedy flag + version info)
    log_verbose "Running: brew outdated --verbose && brew outdated --cask --greedy --verbose"

    # Check formulas (with version info)
    outdated_formulas=""
    if outdated_formulas=$(brew outdated --verbose 2>&1); then
        log_verbose "Formula check completed"
    else
        log_verbose "Formula check failed with exit code: $?"
    fi

    # Check casks (including greedy + version info)
    outdated_casks=""
    if outdated_casks=$(brew outdated --cask --greedy --verbose 2>&1); then
        log_verbose "Cask check completed"
    else
        log_verbose "Cask check failed with exit code: $?"
    fi

    # Show results separately for better organization
    outdated_brew=""
    if [[ -n "$outdated_formulas" ]]; then
        formula_count=$(echo "$outdated_formulas" | wc -l | tr -d ' ')
        log_output "📦 Homebrew Formulas (${formula_count} updates):"
        log_output "$outdated_formulas"
        outdated_brew="formulas"
    fi

    if [[ -n "$outdated_casks" ]]; then
        cask_count=$(echo "$outdated_casks" | wc -l | tr -d ' ')
        log_output ""
        log_output "🖥️ GUI Applications/Casks (${cask_count} updates):"
        log_output "$outdated_casks"
        if [[ -n "$outdated_brew" ]]; then
            outdated_brew="$outdated_brew + casks"
        else
            outdated_brew="casks"
        fi
    fi

    if [[ -n "$outdated_brew" ]]; then
        updates_found=true
        log_verbose "Homebrew updates available"
    else
        log_output "All Homebrew packages are up to date"
        log_verbose "No Homebrew updates"
    fi
    log_output ""
else
    log_verbose "Homebrew not available"
fi

# Check APT (Ubuntu/Debian)
if command -v apt >/dev/null 2>&1; then
    log_subsection "APT"
    checked_pms+=("apt")

    # UPDATE REGISTRY
    log_output "Updating APT registry..."
    log_verbose "Running: sudo apt update"
    if sudo apt update 2>&1 | tee -a "${LOG_FILE}" >/dev/null; then
        log_verbose "apt update completed successfully"
    else
        log_output "Warning: apt update had issues"
        log_verbose "apt update failed with exit code: $?"
    fi

    # CHECK FOR UPDATES
    log_verbose "Running: apt list --upgradable"
    if upgradable_apt=$(apt list --upgradable 2>/dev/null | head -20); then
        upgradable_count=$(echo "$upgradable_apt" | grep -v "^Listing" | wc -l | tr -d ' ' || echo "0")
        upgradable_count="${upgradable_count//[$'\r\n']/}"
        if [[ ${upgradable_count:-0} -gt 0 ]]; then
            log_output "Available updates (showing first 20):"
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
    log_output ""
else
    log_verbose "APT not available"
fi

# Check Pacman (Arch)
if command -v pacman >/dev/null 2>&1; then
    log_subsection "Pacman"
    checked_pms+=("pacman")

    # UPDATE REGISTRY
    log_output "Updating Pacman registry..."
    log_verbose "Running: sudo pacman -Sy"
    if sudo pacman -Sy 2>&1 | tee -a "${LOG_FILE}" >/dev/null; then
        log_verbose "pacman -Sy completed successfully"
    else
        log_output "Warning: pacman -Sy had issues"
        log_verbose "pacman -Sy failed with exit code: $?"
    fi

    # CHECK FOR UPDATES
    log_verbose "Running: pacman -Qu"
    if upgradable_pacman=$(pacman -Qu 2>/dev/null); then
        if [[ -n "$upgradable_pacman" ]]; then
            log_output "Available updates:"
            log_output "$upgradable_pacman"
            updates_found=true
            log_verbose "Pacman updates available"
        else
            log_output "All Pacman packages are up to date"
            log_verbose "No Pacman updates"
        fi
    else
        log_output "Error checking Pacman updates"
        log_verbose "pacman -Qu failed"
    fi
    log_output ""
else
    log_verbose "Pacman not available"
fi

# Check Scoop (Windows)
if command -v scoop >/dev/null 2>&1; then
    log_subsection "Scoop"
    checked_pms+=("scoop")

    # UPDATE REGISTRY
    log_output "Updating Scoop registry..."
    log_verbose "Running: scoop update"
    if scoop update 2>&1 | tee -a "${LOG_FILE}" >/dev/null; then
        log_verbose "scoop update completed successfully"
    else
        log_output "Warning: scoop update had issues"
        log_verbose "scoop update failed with exit code: $?"
    fi

    # CHECK FOR UPDATES
    log_verbose "Running: scoop status"
    if outdated_scoop=$(scoop status 2>&1); then
        if echo "$outdated_scoop" | grep -q "Updates are available"; then
            log_output "Available updates:"
            log_output "$outdated_scoop"
            updates_found=true
            log_verbose "Scoop updates available"
        else
            log_output "All Scoop packages are up to date"
            log_verbose "No Scoop updates"
        fi
    else
        log_output "Error checking Scoop updates"
        log_verbose "scoop status failed"
    fi
    log_output ""
else
    log_verbose "Scoop not available"
fi

# Summary
log_section "Check Summary"

if [[ ${#checked_pms[@]} -eq 0 ]]; then
    log_warn "No package managers found"
    log_debug "No package managers detected on this system"
else
    log_success "Checked package managers: ${checked_pms[*]}"
    if [[ "$updates_found" == true ]]; then
        log_warn "Updates are available - run 'just upgrade-system-packages' to upgrade"
    else
        log_success "All system packages are up to date"
    fi
fi

log_duration "${START_TIME}"
finalize_log "SUCCESS"

log_info "Check session logged to: ${LOG_FILE}"

exit 0
