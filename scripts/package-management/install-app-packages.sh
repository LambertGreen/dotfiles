#!/usr/bin/env bash
# Install application-specific package managers (zinit, elpaca, lazy.nvim)
# These are packages within specific applications

set -euo pipefail

# Set up logging
DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_DIR="${DOTFILES_ROOT}/.logs"
LOG_FILE="${LOG_DIR}/install-app-packages-$(date +%Y%m%d-%H%M%S).log"

# Create log directory if it doesn't exist
mkdir -p "${LOG_DIR}"

# Initialize log file
{
    echo "Install App Packages Log"
    echo "========================"
    echo "Date: $(date)"
    echo "Machine: $(hostname 2>/dev/null || echo 'unknown')"
    echo "User: ${USER:-$(whoami)}"
    echo "========================"
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

log_output "📦 Installing application package managers..."
log_output ""

# This is essentially what init-dev-packages.sh does
# We're just renaming for clarity
log_verbose "Delegating to init-dev-packages.sh for app package installation"
"${DOTFILES_ROOT}/scripts/package-management/init-dev-packages.sh"

log_output ""
log_output "✅ App packages installation complete"
log_output "📝 Log saved to: ${LOG_FILE}"
