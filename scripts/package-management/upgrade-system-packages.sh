#!/usr/bin/env bash
# Upgrade system packages (both admin and user levels)
# Orchestrates the upgrades in the correct order

set -euo pipefail

# Set up logging
DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_DIR="${DOTFILES_ROOT}/.logs"
LOG_FILE="${LOG_DIR}/upgrade-system-packages-$(date +%Y%m%d-%H%M%S).log"

# Create log directory if it doesn't exist
mkdir -p "${LOG_DIR}"

# Initialize log file
{
    echo "Upgrade System Packages Log"
    echo "==========================="
    echo "Date: $(date)"
    echo "Machine: $(hostname 2>/dev/null || echo 'unknown')"
    echo "User: ${USER:-$(whoami)}"
    echo "==========================="
    echo ""
} > "${LOG_FILE}"

# Function to log both to console and file
log_output() {
    echo "$1" | tee -a "${LOG_FILE}"
}

# Function to log only to file
log_verbose() {
    echo "$1" >> "${LOG_FILE}"
}

log_output "🔄 Upgrading system packages..."
log_output ""

# Load machine configuration
if [[ -f "${HOME}/.dotfiles.env" ]]; then
    source "${HOME}/.dotfiles.env"
    log_verbose "Machine class: ${DOTFILES_MACHINE_CLASS:-unknown}"
fi

# Upgrade admin packages first (may require sudo)
log_output "=== Admin-level Package Upgrades ==="
log_output "Note: This may prompt for your password"
if command -v brew >/dev/null 2>&1; then
    if "${DOTFILES_ROOT}/scripts/package-management/brew/upgrade-brew-packages.sh" admin false 2>&1 | tee -a "${LOG_FILE}"; then
        log_output "✅ Admin packages upgraded"
    else
        log_output "⚠️ Some admin package upgrades may have failed"
    fi
else
    log_verbose "Homebrew not available - skipping admin brew upgrades"
fi

log_output ""

# Upgrade user packages (no sudo required)
log_output "=== User-level Package Upgrades ==="
if command -v brew >/dev/null 2>&1; then
    if "${DOTFILES_ROOT}/scripts/package-management/brew/upgrade-brew-packages.sh" user false 2>&1 | tee -a "${LOG_FILE}"; then
        log_output "✅ User packages upgraded"
    else
        log_output "⚠️ Some user package upgrades may have failed"
    fi
else
    log_verbose "Homebrew not available - skipping user brew upgrades"
fi

log_output ""
log_output "✅ System packages upgrade complete"
log_output "📝 Log saved to: ${LOG_FILE}"
