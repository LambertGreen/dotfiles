#!/usr/bin/env bash
# Stow wrapper with logging

set -euo pipefail

# Set up logging
DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${DOTFILES_ROOT}/logs"
LOG_FILE="${LOG_DIR}/stow-$(date +%Y%m%d-%H%M%S).log"

# Create log directory if it doesn't exist
mkdir -p "${LOG_DIR}"

# Initialize log file with header
{
    echo "Stow Operation Log"
    echo "=================="
    echo "Date: $(date)"
    echo "Machine: $(hostname 2>/dev/null || echo 'unknown')"
    echo "User: ${USER:-$(whoami)}"
    echo "Script: $0 $*"
    echo "=================="
    echo ""
} > "${LOG_FILE}"

# Function to log both to console and file
log_output() {
    echo "$1" | tee -a "${LOG_FILE}"
}

# Function to log only to file (for verbose details)
log_verbose() {
    echo "$1" >> "${LOG_FILE}"
}

# Get platform from argument or environment
PLATFORM="$1"

log_output "🔗 Stowing ${PLATFORM} configurations using environment-driven approach..."

# Check if configured
if [ ! -f "$HOME/.dotfiles.env" ]; then
    log_output "❌ Configuration file missing. Run: just configure"
    exit 1
fi

# Load configuration
source "$HOME/.dotfiles.env"
log_verbose "Loaded configuration from ~/.dotfiles.env"
log_verbose "DOTFILES_PLATFORM: ${DOTFILES_PLATFORM:-'not set'}"
log_verbose "DOTFILES_MACHINE_CLASS: ${DOTFILES_MACHINE_CLASS:-'not set'}"

# Use stow.txt file from machine class directory (single source of truth)
STOW_FILE="machine-classes/${DOTFILES_MACHINE_CLASS}/stow/stow.txt"
log_output "📂 Stowing configurations using machine class stow.txt..."
log_verbose "Using stow file: ${STOW_FILE}"

if [ ! -f "${STOW_FILE}" ]; then
    log_output "❌ Stow configuration file not found: ${STOW_FILE}"
    exit 1
fi

# Read stow.txt and process each line
cd configs
while IFS= read -r stow_entry; do
    # Skip empty lines and comments
    [[ -z "$stow_entry" || "$stow_entry" =~ ^[[:space:]]*# ]] && continue
    
    # Extract directory and package name
    stow_dir=$(dirname "$stow_entry")
    stow_package=$(basename "$stow_entry")
    
    log_verbose "Stowing: $stow_entry (dir: $stow_dir, package: $stow_package)"
    
    if [ -d "$stow_dir/$stow_package" ]; then
        cd "$stow_dir"
        if stow --dotfiles --target="$HOME" "$stow_package" 2>>"${LOG_FILE}"; then
            log_verbose "Successfully stowed: $stow_entry"
        else
            log_verbose "Failed to stow: $stow_entry (exit code: $?)"
            log_output "⚠️  Some configs may not apply"
        fi
        cd - >/dev/null
    else
        log_verbose "Directory not found, skipping: $stow_dir/$stow_package"
    fi
done < "../${STOW_FILE}"

cd ..
log_verbose "Returned to root directory"

log_output ""
log_output "✅ Stow operation completed (GNU Stow only reports errors)"
log_output ""
log_output "💡 To verify symlinks were created successfully, run:"
log_output "   just check-health"
log_output ""
log_output "📝 Note: The health check will show:"
log_output "   - Number of symlinks created"
log_output "   - Any broken or missing links"
log_output "   - Overall system health status"

log_output ""
log_output "📝 Stow session logged to: ${LOG_FILE}"

# Log final status to file
{
    echo ""
    echo "=== STOW COMPLETION ==="
    echo "Platform: $PLATFORM"
    echo "DOTFILES_PLATFORM: ${DOTFILES_PLATFORM:-'not set'}"
    echo "DOTFILES_MACHINE_CLASS: ${DOTFILES_MACHINE_CLASS:-'not set'}"
    echo "Status: SUCCESS"
    echo "======================="
    echo ""
    echo "Stow completed at: $(date)"
} >> "${LOG_FILE}"