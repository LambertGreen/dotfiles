#!/usr/bin/env bash
# Package manager orchestrator - calls individual package managers in correct order

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

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

# Determine package manager order based on OS
get_package_manager_order() {
    local machine_class="$1"
    local os=$(echo "${machine_class}" | cut -d'_' -f3)
    
    case "${os}" in
        mac)
            echo "brew pip npm gem cargo"
            ;;
        ubuntu)
            echo "apt brew pip npm gem cargo"
            ;;
        arch)
            echo "pacman pip npm gem cargo"
            ;;
        win)
            echo "scoop choco pip npm"
            ;;
        *)
            # Default order - system PMs first, then language PMs
            echo "apt pacman brew pip npm gem cargo"
            ;;
    esac
}

# Get dev package manager order
get_dev_package_manager_order() {
    echo "emacs neovim zsh"
}

# Run system packages
run_system_packages() {
    local pm_order=$(get_package_manager_order "${DOTFILES_MACHINE_CLASS}")
    
    log_output "🔧 Installing System Packages"
    log_output "=============================="
    
    for pm in ${pm_order}; do
        local pm_script="${SCRIPT_DIR}/${pm}/install-${pm}-packages.sh"
        
        if [[ -f "$pm_script" ]] && has_package_config "$pm"; then
            log_info "Running $pm package manager..."
            if "$pm_script"; then
                log_success "$pm completed successfully"
            else
                log_error "$pm failed"
                failed_pms+=("$pm")
            fi
        else
            log_info "Skipping $pm (no script or config)"
            skipped_pms+=("$pm")
        fi
    done
}

# Run dev packages  
run_dev_packages() {
    local dev_pm_order=$(get_dev_package_manager_order)
    
    log_output ""
    log_output "⚡ Installing Development Packages"
    log_output "=================================="
    
    for pm in ${dev_pm_order}; do
        local pm_script="${SCRIPT_DIR}/${pm}/init-${pm}-packages.sh"
        
        if [[ -f "$pm_script" ]] && check_package_manager "$pm"; then
            log_info "Running $pm package manager..."
            if "$pm_script"; then
                log_success "$pm completed successfully"
            else
                log_error "$pm failed"
                failed_pms+=("$pm")
            fi
        else
            log_info "Skipping $pm (no script or not available)"
            skipped_pms+=("$pm")
        fi
    done
}

# Main execution
main() {
    local mode="${1:-all}"
    
    log_output "📦 Package Manager Orchestrator"
    log_output "==============================="
    log_output "Machine class: ${DOTFILES_MACHINE_CLASS}"
    log_output "Mode: $mode"
    log_output ""
    
    case "$mode" in
        system)
            run_system_packages
            ;;
        dev)
            run_dev_packages
            ;;
        all|*)
            run_system_packages
            run_dev_packages
            ;;
    esac
    
    print_summary "Package Manager Orchestrator"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi