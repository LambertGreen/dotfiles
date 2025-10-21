#!/usr/bin/env bash
# Setup script to pin packages that require admin privileges
# This prevents them from being upgraded during regular brew upgrade

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Load machine configuration
if [[ -f "${HOME}/.dotfiles.env" ]]; then
    source "${HOME}/.dotfiles.env"
fi

# Load shared utilities
source "${DOTFILES_ROOT}/scripts/package-management/shared/common.sh"
source "${DOTFILES_ROOT}/scripts/package-management/shared/package-utils.sh"

# Function to pin admin-required formulas
pin_admin_formulas() {
    local config_dir
    config_dir=$(get_machine_config_dir "brew")
    local brewfile="${config_dir}/Brewfile.formulas.requires_admin"

    if [[ ! -f "$brewfile" ]]; then
        log_info "No admin-required formulas to pin"
        return 0
    fi

    log_info "Pinning admin-required formulas..."

    # Extract formula names and pin them
    local formulas
    if formulas=$(grep "^brew " "$brewfile" | sed 's/brew "\([^"]*\)".*/\1/'); then
        while IFS= read -r formula; do
            if [[ -n "$formula" ]]; then
                # Check if formula is installed
                if brew list --formula | grep -q "^${formula}$"; then
                    # Pin the formula
                    if brew pin "$formula" 2>/dev/null; then
                        log_success "Pinned: $formula"
                    else
                        log_info "Already pinned or error pinning: $formula"
                    fi
                else
                    log_info "Not installed (skipping): $formula"
                fi
            fi
        done <<< "$formulas"
    fi
}

# Function to unpin admin-required formulas (for manual upgrade)
unpin_admin_formulas() {
    local config_dir
    config_dir=$(get_machine_config_dir "brew")
    local brewfile="${config_dir}/Brewfile.formulas.requires_admin"

    if [[ ! -f "$brewfile" ]]; then
        return 0
    fi

    log_info "Unpinning admin-required formulas..."

    # Extract formula names and unpin them
    local formulas
    if formulas=$(grep "^brew " "$brewfile" | sed 's/brew "\([^"]*\)".*/\1/'); then
        while IFS= read -r formula; do
            if [[ -n "$formula" ]]; then
                brew unpin "$formula" 2>/dev/null || true
            fi
        done <<< "$formulas"
    fi
}

# Main execution
main() {
    case "${1:-setup}" in
        setup)
            pin_admin_formulas
            ;;
        unpin)
            unpin_admin_formulas
            ;;
        *)
            log_error "Usage: $0 [setup|unpin]"
            exit 1
            ;;
    esac
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
