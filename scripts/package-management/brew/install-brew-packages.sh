#!/usr/bin/env bash
# Brew package installation script

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
LOG_DIR="${DOTFILES_ROOT}/logs"

# Initialize Homebrew environment (Docker RUN doesn't source shell files)
if [[ -f "/home/linuxbrew/.linuxbrew/bin/brew" ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
elif [[ -f "/opt/homebrew/bin/brew" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

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

# Brew installation function
install_brew_packages() {
    local config_dir=$(get_machine_config_dir "brew")
    
    if [[ ! -f "${config_dir}/Brewfile" ]]; then
        log_error "No Brewfile found in ${config_dir}"
        return 1
    fi
    
    log_info "Installing Homebrew packages..."
    
    # Check what's outdated before installing
    log_info "Checking for Homebrew package updates..."
    if outdated_before=$(brew outdated 2>&1); then
        if [[ -n "$outdated_before" ]]; then
            log_info "Outdated packages before install:"
            echo "$outdated_before" | head -10
        else
            log_info "No outdated packages before install"
        fi
    fi
    
    # Install from Brewfile
    if ! brew bundle install --file="${config_dir}/Brewfile" --no-upgrade; then
        log_error "Failed to install packages from Brewfile"
        return 1
    fi
    
    # Check what got installed/upgraded
    if outdated_after=$(brew outdated 2>&1); then
        if [[ -n "$outdated_after" ]]; then
            log_info "Still outdated after install:"
            echo "$outdated_after" | head -10
        else
            log_info "All packages up to date after install"
        fi
    fi
    
    # Check for sudo-required casks
    if [[ -f "${config_dir}/Brewfile.casks-sudo" ]]; then
        log_info "Sudo-required casks found in Brewfile.casks-sudo"
        log_info "Run separately: just install-brew-sudo"
    fi
    
    return 0
}

# Main execution
main() {
    log_output "Homebrew Package Installation"
    log_output "============================="
    log_output "Machine class: ${DOTFILES_MACHINE_CLASS}"
    log_output ""
    
    execute_package_manager "brew" "install_brew_packages"
    
    print_summary "Homebrew Package Installation"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi