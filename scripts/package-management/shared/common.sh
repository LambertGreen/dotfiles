#!/usr/bin/env bash
# Shared utilities for package manager initialization scripts
# This is now a compatibility wrapper for the enhanced logging system

set -euo pipefail

# Get script directory
COMMON_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$COMMON_SCRIPT_DIR/../../.." && pwd)}"

# Set default log configuration if not already set
LOG_DIR="${LOG_DIR:-${DOTFILES_ROOT}/.logs}"
LOG_FILE="${LOG_FILE:-${LOG_DIR}/dev-package-init-$(date +%Y%m%d-%H%M%S).log}"

# Set LOG_PREFIX if not already set (use calling script name)
if [[ -z "${LOG_PREFIX:-}" ]]; then
    CALLING_SCRIPT="${BASH_SOURCE[1]:-unknown}"
    SCRIPT_NAME="$(basename "$CALLING_SCRIPT" .sh)"
    case "$SCRIPT_NAME" in
        install-brew-packages) LOG_PREFIX="BREW-INSTALL" ;;
        upgrade-brew-packages) LOG_PREFIX="BREW-UPGRADE" ;;
        install-apt-packages) LOG_PREFIX="APT-INSTALL" ;;
        install-pacman-packages) LOG_PREFIX="PACMAN-INSTALL" ;;
        install-pip-packages) LOG_PREFIX="PIP-INSTALL" ;;
        install-npm-packages) LOG_PREFIX="NPM-INSTALL" ;;
        install-gem-packages) LOG_PREFIX="GEM-INSTALL" ;;
        install-cargo-packages) LOG_PREFIX="CARGO-INSTALL" ;;
        *) LOG_PREFIX="PKG-MGMT" ;;
    esac
fi

# Source the enhanced logging utilities
source "${DOTFILES_ROOT}/scripts/package-management/shared/logging.sh"

# Initialize log if not already initialized
if [[ ! -f "${LOG_FILE}" ]] || ! grep -q "Log Session Started" "${LOG_FILE}" 2>/dev/null; then
    initialize_log "$(basename "${BASH_SOURCE[1]:-unknown}")"
fi

# For backward compatibility, provide wrapper functions that match old interface
# but use new logging underneath

# The old log_output function - map to log_info for generic output
log_output() {
    local message="$1"
    # Check for special markers and route appropriately
    if [[ "$message" == *"✅"* ]] || [[ "$message" == *"Success"* ]]; then
        log_success "$message"
    elif [[ "$message" == *"⚠️"* ]] || [[ "$message" == *"Warning"* ]]; then
        log_warn "$message"
    elif [[ "$message" == *"❌"* ]] || [[ "$message" == *"ERROR"* ]] || [[ "$message" == *"Failed"* ]]; then
        log_error "$message"
    elif [[ "$message" == *"===="* ]]; then
        # Section headers - just output without prefix
        echo "$message"
        echo "[$(get_timestamp)] [${LOG_PREFIX}] [OUTPUT] ${message}" >> "${LOG_FILE}"
    elif [[ -z "$message" ]]; then
        # Empty line
        echo ""
        echo "[$(get_timestamp)] [${LOG_PREFIX}] [OUTPUT] " >> "${LOG_FILE}"
    else
        log_info "$message"
    fi
}

# The old log_verbose is now log_debug
log_verbose() {
    log_debug "$1"
}

# These already exist in logging.sh with same interface:
# - log_error
# - log_success
# - log_info
# - command_exists

# Initialize arrays for tracking (backward compatibility)
initialize_tracking_arrays() {
    initialized_pms=()
    failed_pms=()
    skipped_pms=()
}

# Print summary with enhanced formatting
print_summary() {
    local script_name="$1"

    log_section "${script_name} Summary"

    if [[ ${#initialized_pms[@]} -gt 0 ]]; then
        log_success "Successfully initialized: ${initialized_pms[*]}"
    fi

    if [[ ${#failed_pms[@]} -gt 0 ]]; then
        log_error "Failed to initialize: ${failed_pms[*]}"
    fi

    if [[ ${#skipped_pms[@]} -gt 0 ]]; then
        log_info "Skipped (not available): ${skipped_pms[*]}"
    fi

    log_output ""
    log_info "Full log available at: ${LOG_FILE}"
}
