#!/usr/bin/env bash
# Install system packages (both admin and user levels)
# Orchestrates the installation in the correct order

set -euo pipefail

# Set up logging
DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_DIR="${DOTFILES_ROOT}/.logs"
LOG_FILE="${LOG_DIR}/install-system-packages-$(date +%Y%m%d-%H%M%S).log"

# Create log directory if it doesn't exist
mkdir -p "${LOG_DIR}"

# Initialize log file
{
    echo "Install System Packages Log"
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

log_output "📦 Installing system packages..."
log_output ""

# Load machine configuration
if [[ -f "${HOME}/.dotfiles.env" ]]; then
    source "${HOME}/.dotfiles.env"
    log_verbose "Machine class: ${DOTFILES_MACHINE_CLASS:-unknown}"
fi

# Install admin packages first (may require sudo)
log_output "=== Admin-level Packages ==="
log_output "Note: This may prompt for your password"
if "${DOTFILES_ROOT}/scripts/package-management/brew/install-brew-packages.sh" admin 2>&1 | tee -a "${LOG_FILE}"; then
    log_output "✅ Admin packages installed"
else
    log_output "⚠️ Some admin packages may have failed"
fi

log_output ""

# Install user packages (no sudo required)
log_output "=== User-level Packages ==="
if "${DOTFILES_ROOT}/scripts/package-management/brew/install-brew-packages.sh" user 2>&1 | tee -a "${LOG_FILE}"; then
    log_output "✅ User packages installed"
else
    log_output "⚠️ Some user packages may have failed"
fi

log_output ""
log_output "✅ System packages installation complete"
log_output "📝 Log saved to: ${LOG_FILE}"
