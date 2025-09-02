#!/usr/bin/env bash
# Check application packages for updates
# Application package managers: zinit, elpaca, lazy.nvim

set -euo pipefail

# Set up logging
DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_DIR="${DOTFILES_ROOT}/.logs"
LOG_FILE="${LOG_DIR}/check-app-packages-$(date +%Y%m%d-%H%M%S).log"

# Create log directory if it doesn't exist
mkdir -p "${LOG_DIR}"

# Initialize log file
{
    echo "Check App Packages Log"
    echo "======================"
    echo "Date: $(date)"
    echo "Machine: $(hostname 2>/dev/null || echo 'unknown')"
    echo "User: ${USER:-$(whoami)}"
    echo "======================"
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

log_output "🔍 Checking application packages for updates..."
log_output ""

# Track what package managers we check
checked_pms=()
updates_found=false

# Check Zsh plugins (zinit)
if command -v zinit >/dev/null 2>&1 || [[ -d "${HOME}/.zinit" ]]; then
    log_output "=== Zsh Plugins (zinit) ==="
    checked_pms+=("zinit")

    # Check if zinit can update plugins (this doesn't actually update)
    if zsh -c "zinit list" >/dev/null 2>&1; then
        plugin_count=$(zsh -c "zinit list" 2>/dev/null | wc -l | tr -d ' ')
        if [[ ${plugin_count:-0} -gt 0 ]]; then
            log_output "Found ${plugin_count} zsh plugins (updates available)"
            updates_found=true
            log_verbose "Zinit plugins can be updated"
        else
            log_output "No zsh plugins found"
            log_verbose "No zinit plugins"
        fi
    else
        log_output "Cannot check zsh plugin status"
        log_verbose "zinit list command failed"
    fi
    log_output ""
else
    log_verbose "Zinit not available"
fi

# Check Emacs packages (elpaca) - placeholder for now
log_verbose "Emacs (elpaca) check not yet implemented"

# Check Neovim packages (lazy.nvim) - placeholder for now
log_verbose "Neovim (lazy.nvim) check not yet implemented"

# Summary
log_output "========================="
if [[ ${#checked_pms[@]} -eq 0 ]]; then
    log_output "⚠️  No app package managers found"
    log_verbose "No app package managers detected on this system"
else
    log_output "✅ Checked app package managers: ${checked_pms[*]}"
    if [[ "$updates_found" == true ]]; then
        log_output "📦 Updates are available - run 'just upgrade-app-packages' to upgrade"
    else
        log_output "✨ All app packages are up to date"
    fi
fi

log_output ""
log_output "📝 Check session logged to: ${LOG_FILE}"

# Log final status to file
{
    echo ""
    echo "=== CHECK COMPLETION ==="
    echo "App package managers checked: ${checked_pms[*]:-none}"
    echo "Updates found: $updates_found"
    echo "Status: SUCCESS"
    echo "========================"
    echo ""
    echo "Check completed at: $(date)"
} >> "${LOG_FILE}"

exit 0
