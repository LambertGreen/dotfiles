#!/usr/bin/env bash
# Brew package upgrade script v3 - uses packages.user and packages.admin
# Clean design without legacy if/else blocks

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Initialize Homebrew environment
if [[ -f "/home/linuxbrew/.linuxbrew/bin/brew" ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
elif [[ -f "/opt/homebrew/bin/brew" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Load shared utilities
source "${DOTFILES_ROOT}/scripts/package-management/shared/common.sh"
source "${DOTFILES_ROOT}/scripts/package-management/shared/package-utils.sh"

# Load machine configuration
if [[ -f "${HOME}/.dotfiles.env" ]]; then
    source "${HOME}/.dotfiles.env"
fi

# Parse command line arguments
PACKAGE_LEVEL="${1:-user}"  # user, admin, or all
INTERACTIVE="${2:-false}"

# Get machine brew directory
get_brew_config_dir() {
    echo "${DOTFILES_ROOT}/machine-classes/${DOTFILES_MACHINE_CLASS}/brew"
}

# Upgrade packages from a specific file
upgrade_from_file() {
    local package_file="$1"
    local level_name="$2"

    if [[ ! -f "$package_file" ]]; then
        log_info "No $level_name packages file found at: $package_file"
        return 1
    fi

    log_info "Upgrading $level_name packages from: $(basename "$package_file")"

    # Use brew bundle for upgrade
    if brew bundle install --file="$package_file"; then
        log_success "$level_name packages upgraded successfully"
        return 0
    else
        log_error "Some $level_name packages failed to upgrade"
        return 1
    fi
}

# Main upgrade function
main() {
    local brew_dir
    brew_dir=$(get_brew_config_dir)

    log_output "🍺 Homebrew Package Upgrade"
    log_output "=========================="
    log_output "Package level: $PACKAGE_LEVEL"
    log_output "Machine class: ${DOTFILES_MACHINE_CLASS}"
    log_output ""

    # Update Homebrew first
    log_info "Updating Homebrew..."
    brew update || log_info "Homebrew update had issues, continuing anyway..."

    case "$PACKAGE_LEVEL" in
        user)
            upgrade_from_file "$brew_dir/packages.user" "user-level"
            ;;
        admin)
            log_info "Note: Admin packages may prompt for your password"
            upgrade_from_file "$brew_dir/packages.admin" "admin-level"
            ;;
        all)
            upgrade_from_file "$brew_dir/packages.user" "user-level"
            echo ""
            log_info "Note: Admin packages may prompt for your password"
            upgrade_from_file "$brew_dir/packages.admin" "admin-level"
            ;;
        *)
            log_error "Invalid package level: $PACKAGE_LEVEL"
            log_error "Valid options: user, admin, all"
            return 1
            ;;
    esac

    # Cleanup old versions
    log_info "Cleaning up old versions..."
    brew cleanup || log_info "Cleanup had issues"
    log_success "Cleanup completed"

    log_output ""
    log_output "✅ Homebrew upgrade process completed"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
