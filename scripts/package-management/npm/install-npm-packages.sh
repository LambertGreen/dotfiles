#!/usr/bin/env bash
# NPM package installation script

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
LOG_DIR="${DOTFILES_ROOT}/logs"

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

# NPM installation function with user-local directory
install_npm_packages() {
    local config_dir=$(get_machine_config_dir "npm")

    if [[ ! -f "${config_dir}/packages.txt" ]]; then
        log_error "No packages.txt found in ${config_dir}"
        return 1
    fi

    # Setup npm user-local directory
    local npm_global_dir="${HOME}/.local/npm"
    mkdir -p "${npm_global_dir}"

    # Configure npm to use user directory
    npm config set prefix "${npm_global_dir}"

    # Ensure the bin directory is in PATH for this session
    export PATH="${npm_global_dir}/bin:${PATH}"

    log_info "Installing NPM packages to user directory (${npm_global_dir})..."

    while IFS= read -r package; do
        [[ -z "${package}" || "${package}" =~ ^# ]] && continue
        log_info "Installing npm package: $package"

        # Install to user directory (no sudo needed)
        if ! npm install -g "${package}" 2>&1 | tee -a "${LOG_FILE}"; then
            log_error "Failed to install npm package: $package"
            return 1
        fi

        log_info "Successfully installed npm package: $package"
    done < "${config_dir}/packages.txt"

    # Inform user about PATH requirement
    log_info "NPM packages installed to ${npm_global_dir}/bin"
    log_info "Ensure ~/.local/npm/bin is in your PATH"

    return 0
}

# Main execution
main() {
    log_output "NPM Package Installation"
    log_output "======================="
    log_output "Machine class: ${DOTFILES_MACHINE_CLASS}"
    log_output ""

    execute_package_manager "npm" "install_npm_packages"

    print_summary "NPM Package Installation"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
