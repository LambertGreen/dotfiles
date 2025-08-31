#!/usr/bin/env bash
# Zsh package initialization script

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

# Zsh package initialization function
init_zsh_packages() {
    local zinit_dir="${HOME}/.zinit"

    log_info "Checking if zsh plugins already installed..."

    if [[ -d "${zinit_dir}/plugins" ]] && [[ -n "$(ls -A "${zinit_dir}/plugins" 2>/dev/null)" ]]; then
        log_info "Zsh plugins already installed, skipping initial setup"
        return 0
    fi

    log_info "Running zsh to trigger zinit plugin installation"

    # Initialize zinit and plugins by running zsh with plugin loading
    if timeout 300 zsh -c "
        source ~/.zshrc 2>/dev/null || true
        # Give zinit time to install plugins
        sleep 10
        # Verify plugins are installed
        if [[ -d ~/.zinit/plugins ]] && [[ -n \"\$(ls -A ~/.zinit/plugins 2>/dev/null)\" ]]; then
            echo 'Zinit plugins installed successfully'
            exit 0
        else
            echo 'Zinit plugin installation failed'
            exit 1
        fi
    " 2>&1; then
        log_success "Zsh plugin initialization completed"
        return 0
    else
        log_error "Zsh plugin initialization failed"
        return 1
    fi
}

# Main execution
main() {
    log_output "Zsh Package Initialization"
    log_output "=========================="
    log_output "Machine class: ${DOTFILES_MACHINE_CLASS}"
    log_output ""

    execute_package_manager "zsh" "init_zsh_packages"

    print_summary "Zsh Package Initialization"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
