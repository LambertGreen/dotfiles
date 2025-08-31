#!/usr/bin/env bash
# Neovim package initialization script

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
LOG_DIR="${DOTFILES_ROOT}/.logs"

# Load shared utilities
source "${DOTFILES_ROOT}/scripts/package-management/shared/common.sh"
source "${DOTFILES_ROOT}/scripts/package-management/shared/package-utils.sh"

# Load machine class configuration
if [[ -f "${HOME}/.dotfiles.env" ]]; then
    source "${HOME}/.dotfiles.env"
else
    log_error "Machine class not configured. Run: ./package-management/scripts/configure-machine-class.sh"
    exit 1
fi

# Initialize tracking
initialize_tracking_arrays

# Neovim package initialization function
init_neovim_packages() {
    local nvim_config_dir="${HOME}/.config/nvim"
    local lazy_dir="${HOME}/.local/share/nvim/lazy"

    if [[ ! -d "$nvim_config_dir" ]]; then
        log_error "Neovim config directory not found: $nvim_config_dir"
        return 1
    fi

    log_info "Checking if neovim plugins already installed..."

    if [[ -d "$lazy_dir" ]] && [[ -n "$(ls -A "$lazy_dir" 2>/dev/null)" ]]; then
        log_info "Neovim plugins already installed, skipping initial setup"
        return 0
    fi

    log_info "Running nvim headless with Lazy sync to trigger plugin installation"

    # Use Lazy! sync which forces a full synchronization
    if timeout 600 nvim --headless "+Lazy! sync" +qa 2>&1; then
        log_success "Neovim plugin initialization completed"
        return 0
    else
        log_error "Neovim plugin initialization failed"
        return 1
    fi
}

# Main execution
main() {
    log_output "Neovim Package Initialization"
    log_output "============================="
    log_output "Machine class: ${DOTFILES_MACHINE_CLASS}"
    log_output ""

    execute_package_manager "nvim" "init_neovim_packages"

    print_summary "Neovim Package Initialization"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
