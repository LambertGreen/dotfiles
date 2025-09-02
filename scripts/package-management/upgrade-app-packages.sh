#!/usr/bin/env bash
# Upgrade application packages
# Application package managers: zinit, elpaca, lazy.nvim

set -euo pipefail

# Set up logging
DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_DIR="${DOTFILES_ROOT}/.logs"
LOG_FILE="${LOG_DIR}/upgrade-app-packages-$(date +%Y%m%d-%H%M%S).log"

# Create log directory if it doesn't exist
mkdir -p "${LOG_DIR}"

# Initialize log file
{
    echo "Upgrade App Packages Log"
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

log_output "🔄 Upgrading application packages..."
log_output ""

# Track what package managers we upgrade
upgraded_pms=()

# Upgrade Zsh plugins (zinit)
if command -v zinit >/dev/null 2>&1 || [[ -d "${HOME}/.zinit" ]]; then
    log_output "=== Zsh Plugins (zinit) ==="
    upgraded_pms+=("zinit")

    if zsh -c "zinit self-update && zinit update --all" 2>&1 | tee -a "${LOG_FILE}"; then
        log_output "✅ Zsh plugins upgraded"
    else
        log_output "⚠️ Some zsh plugin upgrades may have failed"
    fi
    log_output ""
else
    log_verbose "Zinit not available - skipping zsh plugin upgrades"
fi

# Upgrade Emacs packages (elpaca) - placeholder for now
log_verbose "Emacs (elpaca) upgrade not yet implemented"

# Upgrade Neovim packages (lazy.nvim) - placeholder for now
log_verbose "Neovim (lazy.nvim) upgrade not yet implemented"

# Summary
log_output "========================="
if [[ ${#upgraded_pms[@]} -eq 0 ]]; then
    log_output "⚠️  No app package managers found to upgrade"
    log_verbose "No app package managers detected on this system"
else
    log_output "✅ Attempted upgrades for: ${upgraded_pms[*]}"
fi

log_output ""
log_output "📝 Upgrade session logged to: ${LOG_FILE}"

# Log final status to file
{
    echo ""
    echo "=== UPGRADE COMPLETION ==="
    echo "App package managers upgraded: ${upgraded_pms[*]:-none}"
    echo "Status: SUCCESS"
    echo "=========================="
    echo ""
    echo "Upgrade completed at: $(date)"
} >> "${LOG_FILE}"

exit 0
