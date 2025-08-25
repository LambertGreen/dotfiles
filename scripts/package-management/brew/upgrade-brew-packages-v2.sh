#!/usr/bin/env bash
# Brew package upgrade script v2 - uses native brew upgrade with pinning
# This approach is more efficient than listing all packages explicitly

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
LOG_DIR="${DOTFILES_ROOT}/logs"

# Initialize Homebrew environment
if [[ -f "/home/linuxbrew/.linuxbrew/bin/brew" ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
elif [[ -f "/opt/homebrew/bin/brew" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Load machine configuration
if [[ -f "${HOME}/.dotfiles.env" ]]; then
    source "${HOME}/.dotfiles.env"
fi

# Load shared utilities
source "${DOTFILES_ROOT}/scripts/package-management/shared/common.sh"
source "${DOTFILES_ROOT}/scripts/package-management/shared/package-utils.sh"

# Parse command line arguments
UPGRADE_TYPE="${1:-all}"  # all, non_admin, requires_admin
INTERACTIVE="${2:-false}"

# Function to get list of admin-required casks
get_admin_casks() {
    local config_dir
    config_dir=$(get_machine_config_dir "brew")
    local brewfile="${config_dir}/Brewfile.casks.requires_admin"

    if [[ -f "$brewfile" ]]; then
        grep "^cask " "$brewfile" | sed 's/cask "\([^"]*\)".*/\1/' | tr '\n' ' '
    fi
}

# Function to upgrade non-admin packages (formulas + non-admin casks)
upgrade_non_admin() {
    log_info "Upgrading non-admin packages (formulas + casks)..."

    # First ensure admin-required formulas are pinned
    "${SCRIPT_DIR}/setup-pinned-packages.sh" setup

    # Get list of admin-required casks to exclude
    local admin_casks
    admin_casks=$(get_admin_casks)

    if [[ -n "$admin_casks" ]]; then
        log_info "Excluding admin-required casks from upgrade"

        # Get list of outdated casks
        local outdated_casks
        outdated_casks=$(brew outdated --cask --greedy --quiet 2>/dev/null || true)

        if [[ -n "$outdated_casks" ]]; then
            # Filter out admin-required casks
            local casks_to_upgrade=""
            for cask in $outdated_casks; do
                if ! echo "$admin_casks" | grep -q "\b$cask\b"; then
                    casks_to_upgrade="$casks_to_upgrade $cask"
                fi
            done

            # Upgrade formulas (pinned ones will be skipped automatically)
            log_info "Upgrading formulas (pinned admin packages will be skipped)..."
            brew upgrade --formula || true

            # Upgrade non-admin casks
            if [[ -n "$casks_to_upgrade" ]]; then
                log_info "Upgrading non-admin casks: $casks_to_upgrade"
                # shellcheck disable=SC2086
                brew upgrade --cask $casks_to_upgrade || true
            else
                log_info "No non-admin casks to upgrade"
            fi
        else
            # No outdated casks, just upgrade formulas
            log_info "Upgrading formulas (pinned admin packages will be skipped)..."
            brew upgrade --formula || true
            log_info "No casks need upgrading"
        fi
    else
        # No admin casks defined, upgrade everything normally
        log_info "Upgrading all formulas (pinned ones will be skipped)..."
        brew upgrade --formula || true

        log_info "Upgrading all casks..."
        brew upgrade --cask --greedy || true
    fi
}

# Function to upgrade admin-required packages
upgrade_requires_admin() {
    log_info "Upgrading admin-required packages..."

    local config_dir
    config_dir=$(get_machine_config_dir "brew")

    # Temporarily unpin admin formulas for upgrade
    "${SCRIPT_DIR}/setup-pinned-packages.sh" unpin

    # Upgrade admin-required formulas
    local brewfile_formulas="${config_dir}/Brewfile.formulas.requires_admin"
    if [[ -f "$brewfile_formulas" ]]; then
        local formulas
        formulas=$(grep "^brew " "$brewfile_formulas" | sed 's/brew "\([^"]*\)".*/\1/' | tr '\n' ' ')
        if [[ -n "$formulas" ]]; then
            log_info "Upgrading admin-required formulas..."
            # shellcheck disable=SC2086
            brew upgrade $formulas || true
        fi
    fi

    # Re-pin the formulas
    "${SCRIPT_DIR}/setup-pinned-packages.sh" setup

    # Upgrade admin-required casks
    local brewfile_casks="${config_dir}/Brewfile.casks.requires_admin"
    if [[ -f "$brewfile_casks" ]]; then
        local casks
        casks=$(grep "^cask " "$brewfile_casks" | sed 's/cask "\([^"]*\)".*/\1/' | tr '\n' ' ')
        if [[ -n "$casks" ]]; then
            log_info "Upgrading admin-required casks (may require password)..."
            # shellcheck disable=SC2086
            brew upgrade --cask $casks || true
        fi
    fi
}

# Function to upgrade all packages
upgrade_all() {
    log_info "Upgrading all packages..."

    # Temporarily unpin all formulas
    "${SCRIPT_DIR}/setup-pinned-packages.sh" unpin

    # Upgrade all formulas
    log_info "Upgrading all formulas..."
    brew upgrade --formula || true

    # Upgrade all casks
    log_info "Upgrading all casks..."
    brew upgrade --cask --greedy || true

    # Re-pin admin formulas
    "${SCRIPT_DIR}/setup-pinned-packages.sh" setup
}

# Main execution
main() {
    log_output "🍺 Homebrew Upgrade Manager v2"
    log_output "================================"
    log_output "Upgrade type: $UPGRADE_TYPE"
    log_output "Interactive: $INTERACTIVE"
    log_output ""

    # Update Homebrew first
    log_info "Updating Homebrew..."
    if brew update; then
        log_success "Homebrew updated"
    else
        log_info "Homebrew update had issues, continuing anyway..."
    fi

    echo ""

    # Perform upgrades based on type
    case "$UPGRADE_TYPE" in
        non_admin)
            upgrade_non_admin
            ;;
        requires_admin)
            upgrade_requires_admin
            ;;
        all)
            upgrade_all
            ;;
        *)
            log_error "Invalid upgrade type: $UPGRADE_TYPE"
            log_info "Valid options: all, non_admin, requires_admin"
            exit 1
            ;;
    esac

    echo ""

    # Cleanup old versions
    log_info "Cleaning up old versions..."
    if brew cleanup; then
        log_success "Cleanup completed"
    else
        log_info "Cleanup had issues"
    fi

    echo ""
    log_output "✅ Homebrew upgrade process completed"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
