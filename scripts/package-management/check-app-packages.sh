#!/usr/bin/env bash
# Check application packages for updates
# Application package managers: zinit, elpaca, lazy.nvim

set -euo pipefail

# Setup
DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Configure logging
LOG_PREFIX="APP-CHECK"
LOG_DIR="${DOTFILES_ROOT}/.logs"
LOG_FILE="${LOG_DIR}/check-app-packages-$(date +%Y%m%d-%H%M%S).log"

# Source enhanced logging utilities
source "${DOTFILES_ROOT}/scripts/package-management/shared/logging.sh"

# Initialize log
initialize_log "check-app-packages.sh"

# Track timing
START_TIME=$(date +%s)

log_section "Application Package Check"
log_info "Checking application packages for updates..."

# Track what package managers we check
checked_pms=()
updates_found=false

# Check Zsh plugins (zinit)
log_subsection "Zsh Plugins (zinit)"

if command -v zinit >/dev/null 2>&1 || [[ -d "${HOME}/.zinit" ]]; then
    checked_pms+=("zinit")

    # Check if zinit can update plugins (this doesn't actually update)
    if zsh -c "zinit list" >/dev/null 2>&1; then
        plugin_count=$(zsh -c "zinit list" 2>/dev/null | wc -l | tr -d ' ')
        if [[ ${plugin_count:-0} -gt 0 ]]; then
            log_info "Found ${plugin_count} zsh plugins"
            log_warn "Updates may be available for zinit plugins"
            updates_found=true
            log_debug "Zinit plugins can be updated"
        else
            log_info "No zsh plugins found"
            log_debug "No zinit plugins installed"
        fi
    else
        log_error "Cannot check zsh plugin status"
        log_debug "zinit list command failed"
    fi
else
    log_debug "Zinit not available - skipping"
fi

# Check Emacs packages (elpaca) - placeholder for now
log_debug "Emacs (elpaca) check not yet implemented"

# Check Neovim packages (lazy.nvim) - placeholder for now
log_debug "Neovim (lazy.nvim) check not yet implemented"

# Summary
log_section "Check Summary"

if [[ ${#checked_pms[@]} -eq 0 ]]; then
    log_warn "No app package managers found"
    log_debug "No app package managers detected on this system"
else
    log_success "Checked app package managers: ${checked_pms[*]}"
    if [[ "$updates_found" == true ]]; then
        log_warn "Updates are available - run 'just upgrade-app-packages' to upgrade"
    else
        log_success "All app packages are up to date"
    fi
fi

log_duration "${START_TIME}"
finalize_log "SUCCESS"

log_info "Check session logged to: ${LOG_FILE}"

exit 0
