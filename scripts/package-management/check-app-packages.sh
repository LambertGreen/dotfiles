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

    # Check zinit plugins by looking at the plugins directory
    if [[ -d "${HOME}/.zinit/plugins" ]]; then
        if plugin_list=$(ls -1 "${HOME}/.zinit/plugins" 2>/dev/null); then
            if [[ -n "$plugin_list" ]]; then
                plugin_count=$(echo "$plugin_list" | wc -l | tr -d ' ')
                log_info "Found ${plugin_count} zsh plugins:"
                # Format plugin names for better readability (convert user---repo to user/repo)
                formatted_plugins=$(echo "$plugin_list" | sed 's/---/\//g' | sed 's/^/  - /' | head -10)
                log_info "$formatted_plugins"
                if [[ $plugin_count -gt 10 ]]; then
                    log_info "  ... and $((plugin_count - 10)) more plugins"
                fi
                log_warn "Updates may be available for zinit plugins"
                updates_found=true
                log_debug "Zinit has ${plugin_count} plugins installed"
                # Note: zinit self-update and zinit update check for updates
            else
                log_info "No zsh plugins found"
                log_debug "No zinit plugins installed"
            fi
        else
            log_warn "Cannot read zinit plugins directory"
            log_debug "ls command failed on ${HOME}/.zinit/plugins"
        fi
    else
        log_warn "Zinit plugins directory not found"
        log_debug "Expected directory: ${HOME}/.zinit/plugins"
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
