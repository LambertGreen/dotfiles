#!/usr/bin/env bash
# APT package installation script

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

# APT installation function
install_apt_packages() {
    local config_dir=$(get_machine_config_dir "apt")

    if [[ ! -f "${config_dir}/packages.txt" ]]; then
        log_error "No packages.txt found in ${config_dir}"
        return 1
    fi

    log_info "Installing APT packages (may require sudo)..."

    # Update package list first
    sudo apt-get update

    # Use while loop for better Docker compatibility
    while IFS= read -r package || [[ -n "$package" ]]; do
        # Skip empty lines and comments
        [[ -z "$package" || "$package" =~ ^[[:space:]]*# ]] && continue
        # Remove inline comments and trim trailing whitespace
        package="${package%%#*}"
        package="${package%"${package##*[![:space:]]}"}"
        [[ -z "$package" ]] && continue

        log_info "Installing apt package: $package"
        if ! sudo apt-get install -y "$package"; then
            log_error "Failed to install package: $package"
            return 1
        fi
    done < "${config_dir}/packages.txt"

    return 0
}

# Main execution
main() {
    log_output "APT Package Installation"
    log_output "======================="
    log_output "Machine class: ${DOTFILES_MACHINE_CLASS}"
    log_output ""

    execute_package_manager "apt" "install_apt_packages"

    print_summary "APT Package Installation"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
