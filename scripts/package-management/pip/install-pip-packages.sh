#!/usr/bin/env bash
# Pip package installation script

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

# Pip installation function using pipx for CLI tools
install_pip_packages() {
    local config_dir=$(get_machine_config_dir "pip")

    if [[ ! -f "${config_dir}/requirements.txt" ]]; then
        log_error "No requirements.txt found in ${config_dir}"
        return 1
    fi

    # Ensure pipx is available - install if needed
    if ! command -v pipx >/dev/null 2>&1; then
        log_info "pipx not found. Installing pipx via pip..."
        if ! pip3 install --user pipx 2>&1 | tee -a "${LOG_FILE}"; then
            log_error "Failed to install pipx"
            return 1
        fi
        # Add ~/.local/bin to PATH for this session if pipx was just installed
        export PATH="${HOME}/.local/bin:${PATH}"

        # Verify pipx is now available
        if ! command -v pipx >/dev/null 2>&1; then
            log_error "pipx installation succeeded but command not found in PATH"
            return 1
        fi
        log_info "Successfully installed pipx"
    fi

    # Configure pipx to use organized directory structure
    export PIPX_HOME="${HOME}/.local/pipx"
    export PIPX_BIN_DIR="${HOME}/.local/pipx/bin"
    mkdir -p "${PIPX_BIN_DIR}"

    # Ensure pipx bin directory is in PATH for this session
    export PATH="${PIPX_BIN_DIR}:${PATH}"

    log_info "Installing Python CLI tools with pipx (isolated environments)..."

    # Install each package with pipx for isolation
    while IFS= read -r package; do
        # Skip empty lines and comments
        [[ -z "${package}" || "${package}" =~ ^[[:space:]]*# ]] && continue
        # Remove inline comments and trim
        package="${package%%#*}"
        package="${package%"${package##*[![:space:]]}"}";
        [[ -z "${package}" ]] && continue

        log_info "Installing Python package with pipx: $package"

        if ! pipx install "$package" 2>&1 | tee -a "${LOG_FILE}"; then
            log_error "Failed to install Python package: $package"
            return 1
        fi

        log_info "Successfully installed Python package: $package"
    done < "${config_dir}/requirements.txt"

    # Show installed packages
    log_info "Installed pipx packages:"
    pipx list --short 2>/dev/null || log_info "No pipx packages listed"

    # Inform user about PATH requirement
    log_info "Python CLI tools installed via pipx to ~/.local/pipx/bin"
    log_info "Ensure ~/.local/pipx/bin is in your PATH"

    return 0
}

# Main execution
main() {
    log_output "Pip Package Installation"
    log_output "======================="
    log_output "Machine class: ${DOTFILES_MACHINE_CLASS}"
    log_output ""

    execute_package_manager "pip" "install_pip_packages"

    print_summary "Pip Package Installation"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
