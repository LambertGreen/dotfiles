#!/usr/bin/env bash
# Install development language packages (npm, pip, cargo, gem, etc.)
# These are packages from language-specific package managers

set -euo pipefail

# Set up logging
DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_DIR="${DOTFILES_ROOT}/.logs"
LOG_FILE="${LOG_DIR}/install-dev-packages-$(date +%Y%m%d-%H%M%S).log"

# Create log directory if it doesn't exist
mkdir -p "${LOG_DIR}"

# Load shared utilities
source "${DOTFILES_ROOT}/scripts/package-management/shared/common.sh"
source "${DOTFILES_ROOT}/scripts/package-management/shared/package-utils.sh"

# Initialize log file
{
    echo "Install Dev Packages Log"
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

log_output "🔧 Installing development language packages..."
log_output ""

# Load machine configuration
if [[ -f "${HOME}/.dotfiles.env" ]]; then
    source "${HOME}/.dotfiles.env"
    log_verbose "Loaded configuration for machine class: ${DOTFILES_MACHINE_CLASS}"
fi

# Track what we install
installed_pms=()
failed_pms=()

# Install npm packages
if command -v npm >/dev/null 2>&1; then
    log_output "=== NPM Packages ==="
    if "${DOTFILES_ROOT}/scripts/package-management/npm/install-npm-packages.sh" 2>&1 | tee -a "${LOG_FILE}"; then
        installed_pms+=("npm")
        log_output "✅ NPM packages installed"
    else
        failed_pms+=("npm")
        log_output "⚠️ NPM packages failed"
    fi
    log_output ""
fi

# Install pip packages
if command -v pip3 >/dev/null 2>&1 || command -v pipx >/dev/null 2>&1; then
    log_output "=== Python Packages ==="
    if "${DOTFILES_ROOT}/scripts/package-management/pip/install-pip-packages.sh" 2>&1 | tee -a "${LOG_FILE}"; then
        installed_pms+=("pip")
        log_output "✅ Python packages installed"
    else
        failed_pms+=("pip")
        log_output "⚠️ Python packages failed"
    fi
    log_output ""
fi

# Install cargo packages
if command -v cargo >/dev/null 2>&1; then
    log_output "=== Cargo Packages ==="
    if "${DOTFILES_ROOT}/scripts/package-management/cargo/install-cargo-packages.sh" 2>&1 | tee -a "${LOG_FILE}"; then
        installed_pms+=("cargo")
        log_output "✅ Cargo packages installed"
    else
        failed_pms+=("cargo")
        log_output "⚠️ Cargo packages failed"
    fi
    log_output ""
fi

# Install gem packages
if command -v gem >/dev/null 2>&1; then
    log_output "=== Ruby Gems ==="
    if "${DOTFILES_ROOT}/scripts/package-management/gem/install-gem-packages.sh" 2>&1 | tee -a "${LOG_FILE}"; then
        installed_pms+=("gem")
        log_output "✅ Ruby gems installed"
    else
        failed_pms+=("gem")
        log_output "⚠️ Ruby gems failed"
    fi
    log_output ""
fi

# Summary
log_output "========================="
if [[ ${#installed_pms[@]} -gt 0 ]]; then
    log_output "✅ Installed: ${installed_pms[*]}"
fi
if [[ ${#failed_pms[@]} -gt 0 ]]; then
    log_output "⚠️ Failed: ${failed_pms[*]}"
fi

log_output ""
log_output "📝 Log saved to: ${LOG_FILE}"

# Exit with error if any failed
if [[ ${#failed_pms[@]} -gt 0 ]]; then
    exit 1
fi

exit 0
