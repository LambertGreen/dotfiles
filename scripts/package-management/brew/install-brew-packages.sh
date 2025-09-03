#!/usr/bin/env bash
# Brew package installation script v2 - Clean design with packages.user/admin
# No legacy if/else blocks

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
LOG_DIR="${DOTFILES_ROOT}/.logs"

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
    log_error "Machine class not configured. Run: ./scripts/configure-machine-class.sh"
    exit 1
fi

# Parse arguments
PACKAGE_LEVEL="${1:-user}"  # user, admin, or all

# Initialize tracking
initialize_tracking_arrays

# Install packages from a specific file
install_from_file() {
    local package_file="$1"
    local level_name="$2"

    if [[ ! -f "$package_file" ]]; then
        log_info "No $level_name packages file found at: $package_file"
        return 1
    fi

    log_info "Installing $level_name packages from: $(basename "$package_file")"

    # Check what's outdated before installing
    log_info "Checking for outdated packages..."
    if outdated_before=$(brew outdated 2>&1); then
        if [[ -n "$outdated_before" ]]; then
            log_info "Outdated packages before install:"
            echo "$outdated_before" | head -10
        fi
    fi

    # Install from package file
    if brew bundle install --file="$package_file" --no-upgrade; then
        log_success "$level_name packages installed successfully"
        return 0
    else
        log_error "Some $level_name packages failed to install"
        return 1
    fi
}

# Main function
main() {
    local config_dir=$(get_machine_config_dir "brew")

    log_info "Homebrew: ${DOTFILES_MACHINE_CLASS} - ${PACKAGE_LEVEL} packages"

    case "$PACKAGE_LEVEL" in
        user)
            install_from_file "$config_dir/packages.user" "user-level"
            ;;
        admin)
            log_info "Note: Admin packages may prompt for password on real systems"
            install_from_file "$config_dir/packages.admin" "admin-level"
            ;;
        all)
            install_from_file "$config_dir/packages.user" "user-level"
            echo ""
            log_info "Note: Admin packages may prompt for password on real systems"
            install_from_file "$config_dir/packages.admin" "admin-level"
            ;;
        *)
            log_error "Invalid package level: $PACKAGE_LEVEL"
            log_error "Valid options: user, admin, all"
            exit 1
            ;;
    esac

    print_summary "Homebrew Package Installation"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
