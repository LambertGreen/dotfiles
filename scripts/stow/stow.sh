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

# Stow common configurations
log_output "📂 Stowing common configurations..."
log_verbose "Changing to configs/common directory"
cd configs/common

log_verbose "Running: stow --dotfiles --target=$HOME git shell tmux vim"
if stow --dotfiles --target="$HOME" git shell tmux vim 2>>"${LOG_FILE}"; then
    log_verbose "Common stow completed successfully"
else
    log_verbose "Some common configs may not have applied (exit code: $?)"
    log_output "⚠️  Some configs may not apply"
fi

cd ../..
log_verbose "Returned to root directory"

# Stow platform-specific configurations
log_output "📂 Stowing platform-specific configurations..."

case "$PLATFORM" in
    osx)
        if [ -d "configs/osx_only" ]; then
            log_verbose "Found osx_only directory, stowing macOS configs"
            cd configs/osx_only
            log_verbose "Running: stow --dotfiles --target=$HOME *"
            if stow --dotfiles --target="$HOME" * 2>>"${LOG_FILE}"; then
                log_verbose "macOS stow completed successfully"
            else
                log_verbose "Some macOS configs may not have applied (exit code: $?)"
                log_output "⚠️  Some osx configs may not apply"
            fi
            cd ../..
        else
            log_verbose "No osx_only directory found"
        fi
        ;;
    ubuntu|arch)
        if [ -d "configs/linux_only" ]; then
            log_verbose "Found linux_only directory, stowing Linux configs"
            cd configs/linux_only
            log_verbose "Running: stow --dotfiles --target=$HOME *"
            if stow --dotfiles --target="$HOME" * 2>>"${LOG_FILE}"; then
                log_verbose "Linux stow completed successfully"
            else
                log_verbose "Some Linux configs may not have applied (exit code: $?)"
                log_output "⚠️  Some linux configs may not apply"
            fi
            cd ../..
        else
            log_verbose "No linux_only directory found"
        fi
        ;;
    *)
        log_output "⚠️  Unknown platform: $PLATFORM"
        ;;
esac

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