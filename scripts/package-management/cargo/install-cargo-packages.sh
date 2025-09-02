#!/usr/bin/env bash
# Cargo package installation script

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

# Cargo installation function
install_cargo_packages() {
    local config_dir=$(get_machine_config_dir "cargo")

    if [[ ! -f "${config_dir}/packages.txt" ]]; then
        log_error "No packages.txt found in ${config_dir}"
        return 1
    fi

    log_info "Installing Cargo packages..."

    while IFS= read -r package; do
        [[ -z "${package}" || "${package}" =~ ^# ]] && continue
        log_info "Installing cargo package: $package"
        if ! cargo install "${package}"; then
            log_error "Failed to install cargo package: $package"
            return 1
        fi
    done < "${config_dir}/packages.txt"

    return 0
}

# Main execution
main() {
    log_output "Cargo Package Installation"
    log_output "=========================="
    log_output "Machine class: ${DOTFILES_MACHINE_CLASS}"
    log_output ""

    execute_package_manager "cargo" "install_cargo_packages"

    print_summary "Cargo Package Installation"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
