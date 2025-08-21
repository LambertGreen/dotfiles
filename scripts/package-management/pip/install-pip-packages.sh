#!/usr/bin/env bash
# Pip package installation script

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

# Pip installation function
install_pip_packages() {
    local config_dir=$(get_machine_config_dir "pip")
    
    if [[ ! -f "${config_dir}/requirements.txt" ]]; then
        log_error "No requirements.txt found in ${config_dir}"
        return 1
    fi
    
    local pip_cmd="pip3"
    command -v pip3 >/dev/null 2>&1 || pip_cmd="pip"
    
    # Handle externally-managed environments (PEP 668) on macOS/Homebrew
    local pip_flags="--user"
    if [[ "$OSTYPE" == "darwin"* ]] && command -v brew >/dev/null 2>&1; then
        pip_flags="--user --break-system-packages"
    fi
    
    log_info "Installing Python packages with ${pip_cmd}..."
    
    # Check what's outdated before installing
    log_info "Checking for pip package updates..."
    if outdated_pip_before=$(${pip_cmd} list --outdated --user 2>/dev/null || ${pip_cmd} list --outdated 2>/dev/null); then
        if [[ -n "$outdated_pip_before" ]] && [[ $(echo "$outdated_pip_before" | wc -l) -gt 2 ]]; then
            log_info "Outdated pip packages before install:"
            echo "$outdated_pip_before" | head -10
        else
            log_info "No outdated pip packages before install"
        fi
    fi
    
    # Install from requirements.txt
    if ! ${pip_cmd} install ${pip_flags} -r "${config_dir}/requirements.txt"; then
        log_error "Failed to install packages from requirements.txt"
        return 1
    fi
    
    # Check what's still outdated after installing
    if outdated_pip_after=$(${pip_cmd} list --outdated --user 2>/dev/null || ${pip_cmd} list --outdated 2>/dev/null); then
        if [[ -n "$outdated_pip_after" ]] && [[ $(echo "$outdated_pip_after" | wc -l) -gt 2 ]]; then
            log_info "Still outdated pip packages after install:"
            echo "$outdated_pip_after" | head -10
        else
            log_info "All pip packages up to date after install"
        fi
    fi
    
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