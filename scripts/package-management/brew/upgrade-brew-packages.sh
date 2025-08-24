#!/usr/bin/env bash
# Brew package upgrade script with separate handling for formulas and casks

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

# Load shared utilities
source "${DOTFILES_ROOT}/scripts/package-management/shared/common.sh"
source "${DOTFILES_ROOT}/scripts/package-management/shared/package-utils.sh"

# Parse command line arguments
UPGRADE_TYPE="${1:-all}"  # all, formulas, casks
INTERACTIVE="${2:-false}"

# Function to check outdated packages
check_outdated() {
    local package_type="$1"

    case "$package_type" in
        formulas)
            log_info "Checking outdated formulas..."
            brew outdated --formula
            ;;
        casks)
            log_info "Checking outdated casks..."
            brew outdated --cask --greedy
            ;;
        all)
            log_info "Checking all outdated packages..."
            brew outdated --greedy
            ;;
    esac
}

# Function to upgrade formulas
upgrade_formulas() {
    log_info "Upgrading Homebrew formulas..."

    # Check what's outdated first
    if outdated=$(brew outdated --formula 2>&1); then
        if [[ -z "$outdated" ]]; then
            log_success "All formulas are up to date"
            return 0
        fi

        log_info "Outdated formulas:"
        echo "$outdated"
        echo ""

        if [[ "$INTERACTIVE" == "true" ]]; then
            read -p "Proceed with formula upgrades? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "Skipping formula upgrades"
                return 0
            fi
        fi

        # Upgrade formulas only
        if brew upgrade --formula; then
            log_success "Formula upgrades completed"
        else
            log_error "Some formula upgrades failed"
            return 1
        fi
    else
        log_error "Failed to check outdated formulas"
        return 1
    fi
}

# Function to upgrade casks
upgrade_casks() {
    log_info "Upgrading Homebrew casks..."

    # Check what's outdated first
    if outdated=$(brew outdated --cask --greedy 2>&1); then
        if [[ -z "$outdated" ]]; then
            log_success "All casks are up to date"
            return 0
        fi

        log_info "Outdated casks (including auto-updating apps with --greedy):"
        echo "$outdated"
        echo ""

        log_warning "Note: Cask upgrades may require admin password"
        log_warning "Some apps may lose their Dock position or permissions"

        if [[ "$INTERACTIVE" == "true" ]]; then
            read -p "Proceed with cask upgrades? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "Skipping cask upgrades"
                return 0
            fi
        fi

        # Upgrade casks with greedy flag to include auto-updating apps
        # This is the official recommended method as of Homebrew 4.x
        if brew upgrade --cask --greedy; then
            log_success "Cask upgrades completed"
        else
            log_error "Some cask upgrades failed"
            return 1
        fi
    else
        log_error "Failed to check outdated casks"
        return 1
    fi
}

# Main execution
main() {
    log_output "🍺 Homebrew Upgrade Manager"
    log_output "============================"
    log_output "Upgrade type: $UPGRADE_TYPE"
    log_output "Interactive: $INTERACTIVE"
    log_output ""

    # Update Homebrew first
    log_info "Updating Homebrew..."
    if brew update; then
        log_success "Homebrew updated"
    else
        log_warning "Homebrew update had issues, continuing anyway..."
    fi

    echo ""

    # Perform upgrades based on type
    case "$UPGRADE_TYPE" in
        formulas)
            upgrade_formulas
            ;;
        casks)
            upgrade_casks
            ;;
        all)
            upgrade_formulas
            echo ""
            upgrade_casks
            ;;
        *)
            log_error "Invalid upgrade type: $UPGRADE_TYPE"
            log_info "Valid options: all, formulas, casks"
            exit 1
            ;;
    esac

    echo ""

    # Cleanup old versions
    log_info "Cleaning up old versions..."
    if brew cleanup; then
        log_success "Cleanup completed"
    else
        log_warning "Cleanup had issues"
    fi

    echo ""
    log_output "✅ Homebrew upgrade process completed"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
