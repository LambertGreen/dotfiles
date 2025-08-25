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

# Load machine configuration
if [[ -f "${HOME}/.dotfiles.env" ]]; then
    source "${HOME}/.dotfiles.env"
fi

# Load shared utilities
source "${DOTFILES_ROOT}/scripts/package-management/shared/common.sh"
source "${DOTFILES_ROOT}/scripts/package-management/shared/package-utils.sh"

# Parse command line arguments
UPGRADE_TYPE="${1:-all}"  # all, formulas, casks, formulas.non_admin, formulas.requires_admin, casks.non_admin, casks.requires_admin
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

        log_info "Note: Cask upgrades may require admin password"
        log_info "Some apps may lose their Dock position or permissions"

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

# Function to upgrade classified formulas
upgrade_classified_formulas() {
    local classification="$1"
    local config_dir
    config_dir=$(get_machine_config_dir "brew")
    local brewfile="${config_dir}/Brewfile.formulas.${classification}"

    log_info "Upgrading classified formulas (${classification})..."

    if [[ ! -f "$brewfile" ]]; then
        log_info "No classified Brewfile found: $brewfile"
        return 0
    fi

    log_info "Using Brewfile: $brewfile"

    # Extract formula names and upgrade them specifically
    local formulas
    if formulas=$(grep "^brew " "$brewfile" | sed 's/brew "\([^"]*\)".*/\1/' | tr '\n' ' '); then
        if [[ -n "$formulas" ]]; then
            log_info "Upgrading formulas: $formulas"
            # shellcheck disable=SC2086
            if brew upgrade $formulas; then
                log_success "Classified formulas (${classification}) upgrade completed"
            else
                log_error "Some classified formulas (${classification}) upgrades failed"
                return 1
            fi
        else
            log_info "No formulas found in $brewfile"
        fi
    else
        log_error "Failed to parse formulas from $brewfile"
        return 1
    fi
}

# Function to upgrade classified casks
upgrade_classified_casks() {
    local classification="$1"
    local config_dir
    config_dir=$(get_machine_config_dir "brew")
    local brewfile="${config_dir}/Brewfile.casks.${classification}"

    log_info "Upgrading classified casks (${classification})..."

    if [[ ! -f "$brewfile" ]]; then
        log_info "No classified Brewfile found: $brewfile"
        return 0
    fi

    log_info "Using Brewfile: $brewfile"

    if [[ "$classification" == "requires_admin" ]]; then
        log_info "Note: This may require admin password for system integration"
    fi

    # Extract cask names and upgrade them specifically
    local casks
    if casks=$(grep "^cask " "$brewfile" | sed 's/cask "\([^"]*\)".*/\1/' | tr '\n' ' '); then
        if [[ -n "$casks" ]]; then
            log_info "Upgrading casks: $casks"
            # shellcheck disable=SC2086
            if brew upgrade --cask $casks; then
                log_success "Classified casks (${classification}) upgrade completed"
            else
                log_error "Some classified casks (${classification}) upgrades failed"
                return 1
            fi
        else
            log_info "No casks found in $brewfile"
        fi
    else
        log_error "Failed to parse casks from $brewfile"
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
        log_info "Homebrew update had issues, continuing anyway..."
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
        formulas.non_admin)
            upgrade_classified_formulas "non_admin"
            ;;
        formulas.requires_admin)
            upgrade_classified_formulas "requires_admin"
            ;;
        casks.non_admin)
            upgrade_classified_casks "non_admin"
            ;;
        casks.requires_admin)
            upgrade_classified_casks "requires_admin"
            ;;
        *)
            log_error "Invalid upgrade type: $UPGRADE_TYPE"
            log_info "Valid options: all, formulas, casks, formulas.non_admin, formulas.requires_admin, casks.non_admin, casks.requires_admin"
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
