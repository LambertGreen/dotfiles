#!/usr/bin/env bash
# Gem package installation script

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

# Gem installation function
install_gem_packages() {
    local config_dir=$(get_machine_config_dir "gem")
    
    if [[ ! -f "${config_dir}/Gemfile" ]]; then
        log_error "No Gemfile found in ${config_dir}"
        return 1
    fi
    
    log_info "Installing Ruby gems..."
    
    # Install bundler if not present
    if ! gem list bundler -i >/dev/null 2>&1; then
        log_info "Installing bundler..."
        if ! gem install --no-document bundler; then
            log_error "Failed to install bundler"
            return 1
        fi
    fi
    
    # Change to config directory and install gems
    local current_dir=$(pwd)
    cd "${config_dir}"
    
    if ! bundle install; then
        log_error "Failed to install gems from Gemfile"
        cd "${current_dir}"
        return 1
    fi
    
    cd "${current_dir}"
    return 0
}

# Main execution
main() {
    log_output "Gem Package Installation"
    log_output "======================="
    log_output "Machine class: ${DOTFILES_MACHINE_CLASS}"
    log_output ""
    
    execute_package_manager "gem" "install_gem_packages"
    
    print_summary "Gem Package Installation"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi