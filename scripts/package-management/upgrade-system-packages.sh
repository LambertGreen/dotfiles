#!/usr/bin/env bash
# Upgrade system packages (both admin and user levels)
# Orchestrates the upgrades in the correct order

set -euo pipefail

# Setup
DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Configure logging
LOG_PREFIX="SYS-UPGRADE"
LOG_DIR="${DOTFILES_ROOT}/.logs"
LOG_FILE="${LOG_DIR}/upgrade-system-packages-$(date +%Y%m%d-%H%M%S).log"

# Source enhanced logging utilities
source "${DOTFILES_ROOT}/scripts/package-management/shared/logging.sh"
source "${DOTFILES_ROOT}/scripts/package-management/shared/brew-lock-cleanup.sh"

# Initialize log
initialize_log "upgrade-system-packages.sh"

# Track timing
START_TIME=$(date +%s)

log_section "System Package Upgrade"
log_info "Starting system package upgrade process..."

# Clean up any brew locks before starting
cleanup_brew_locks_if_needed

# Load machine configuration
if [[ -f "${HOME}/.dotfiles.env" ]]; then
    source "${HOME}/.dotfiles.env"
    log_debug "Machine class: ${DOTFILES_MACHINE_CLASS:-unknown}"
fi

# Upgrade admin packages first (may require sudo)
log_subsection "Admin-level Package Upgrades"
log_warn "This may prompt for your password"

if command_exists brew; then
    log_info "Upgrading admin packages via Homebrew..."
    if "${DOTFILES_ROOT}/scripts/package-management/brew/upgrade-brew-packages.sh" admin false; then
        log_success "Admin packages upgraded successfully"
    else
        log_warn "Some admin package upgrades may have failed"
    fi
else
    log_debug "Homebrew not available - skipping admin brew upgrades"
fi

# Upgrade user packages (no sudo required)
log_subsection "User-level Package Upgrades"

if command_exists brew; then
    log_info "Upgrading user packages via Homebrew..."
    if "${DOTFILES_ROOT}/scripts/package-management/brew/upgrade-brew-packages.sh" user false; then
        log_success "User packages upgraded successfully"
    else
        log_warn "Some user package upgrades may have failed"
    fi
else
    log_debug "Homebrew not available - skipping user brew upgrades"
fi

log_section "Upgrade Complete"
log_duration "${START_TIME}"
finalize_log "SUCCESS"

log_success "System packages upgrade complete!"
log_info "Log saved to: ${LOG_FILE}"
