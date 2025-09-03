#!/usr/bin/env bash
# Install system packages (both admin and user levels)
# Orchestrates the installation in the correct order

set -euo pipefail

# Setup
DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Configure logging
LOG_PREFIX="SYS-INSTALL"
LOG_DIR="${DOTFILES_ROOT}/.logs"
LOG_FILE="${LOG_DIR}/install-system-packages-$(date +%Y%m%d-%H%M%S).log"

# Source enhanced logging utilities
source "${DOTFILES_ROOT}/scripts/package-management/shared/logging.sh"

# Initialize log
initialize_log "install-system-packages.sh"

# Track timing
START_TIME=$(date +%s)

log_section "System Package Installation"
log_info "Starting system package installation process..."

# Load machine configuration
if [[ -f "${HOME}/.dotfiles.env" ]]; then
    source "${HOME}/.dotfiles.env"
    log_debug "Machine class: ${DOTFILES_MACHINE_CLASS:-unknown}"
fi

# Install admin packages first (may require sudo)
log_subsection "Admin-level Package Installation"
log_warn "This may prompt for your password"

"${DOTFILES_ROOT}/scripts/package-management/brew/install-brew-packages.sh" admin

log_subsection "User-level Package Installation"

"${DOTFILES_ROOT}/scripts/package-management/brew/install-brew-packages.sh" user

log_section "Installation Complete"
log_duration "${START_TIME}"
finalize_log "SUCCESS"

log_success "System packages installation complete!"
log_info "Log saved to: ${LOG_FILE}"
