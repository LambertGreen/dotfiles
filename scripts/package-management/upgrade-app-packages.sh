#!/usr/bin/env bash
# Upgrade application packages
# Application package managers: zinit, elpaca, lazy.nvim

set -euo pipefail

# Setup
DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Configure logging
LOG_PREFIX="APP-UPGRADE"
LOG_DIR="${DOTFILES_ROOT}/.logs"
LOG_FILE="${LOG_DIR}/upgrade-app-packages-$(date +%Y%m%d-%H%M%S).log"

# Source enhanced logging utilities
source "${DOTFILES_ROOT}/scripts/package-management/shared/logging.sh"

# Initialize log
initialize_log "upgrade-app-packages.sh"

# Track timing
START_TIME=$(date +%s)

log_section "Application Package Upgrade"
log_info "Starting application package upgrade process..."

# Track what package managers we upgrade
upgraded_pms=()

# Upgrade Zsh plugins (zinit)
log_subsection "Zsh Plugins (zinit)"

if command -v zinit >/dev/null 2>&1 || [[ -d "${HOME}/.zinit" ]]; then
    upgraded_pms+=("zinit")
    log_info "Upgrading zinit plugins..."

    zsh -c "zinit self-update && zinit update --all"
    log_success "Zsh plugins upgraded successfully"
else
    log_debug "Zinit not available - skipping zsh plugin upgrades"
fi

# Upgrade Emacs packages (elpaca) - placeholder for now
log_debug "Emacs (elpaca) upgrade not yet implemented"

# Upgrade Neovim packages (lazy.nvim) - placeholder for now
log_debug "Neovim (lazy.nvim) upgrade not yet implemented"

# Summary
log_section "Upgrade Summary"

if [[ ${#upgraded_pms[@]} -eq 0 ]]; then
    log_warn "No app package managers found to upgrade"
    log_debug "No app package managers detected on this system"
else
    log_success "Completed upgrades for: ${upgraded_pms[*]}"
fi

log_duration "${START_TIME}"
finalize_log "SUCCESS"

log_info "Upgrade session logged to: ${LOG_FILE}"

exit 0
