#!/usr/bin/env bash
# Verify dev package initial installation completed successfully
# This is separate from checking for updates - this verifies first-time setup worked

set -euo pipefail

# Set up logging
DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_DIR="${DOTFILES_ROOT}/.logs"
LOG_FILE="${LOG_DIR}/verify-dev-package-install-$(date +%Y%m%d-%H%M%S).log"

# Create log directory if it doesn't exist
mkdir -p "${LOG_DIR}"

# Initialize log file with header
{
    echo "Verify Dev Package Installation Log"
    echo "=================================="
    echo "Date: $(date)"
    echo "Machine: $(hostname 2>/dev/null || echo 'unknown')"
    echo "User: ${USER:-$(whoami)}"
    echo "Script: $0 $*"
    echo "=================================="
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

log_output "🔍 Dev Package Installation Verification"
log_output ""

# Load configuration if available
if [[ -f ~/.dotfiles.env ]]; then
    source ~/.dotfiles.env
    log_verbose "Loaded configuration from ~/.dotfiles.env"
    log_verbose "DOTFILES_PLATFORM: ${DOTFILES_PLATFORM:-'not set'}"
    log_verbose "DOTFILES_MACHINE_CLASS: ${DOTFILES_MACHINE_CLASS:-'not set'}"
else
    log_verbose "No ~/.dotfiles.env found"
fi

# Track verification results
verified_pms=()
failed_pms=()

# Verify zsh (zinit plugins)
if command -v zsh >/dev/null 2>&1 && [[ -f "$HOME/.zinit/bin/zinit.zsh" ]]; then
    log_output "=== Verifying Zsh (zinit plugins) ==="

    zsh_verify_start_time=$(date +%s)
    log_verbose "Running: direct zinit plugins directory check to verify plugin installation"
    # Check zinit plugins directory directly instead of using 'zinit list' which can hang
    plugins_dir="$HOME/.zinit/plugins"
    if [[ -d "$plugins_dir" ]]; then
        plugin_count=$(find "$plugins_dir" -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
        # Subtract 1 for the plugins directory itself
        plugin_count=$((plugin_count - 1))
        if [[ ${plugin_count:-0} -gt 0 ]]; then
            zsh_verify_end_time=$(date +%s)
            zsh_verify_duration=$((zsh_verify_end_time - zsh_verify_start_time))
            log_output "✅ Zsh: $plugin_count plugins successfully installed (verified in ${zsh_verify_duration}s)"
            verified_pms+=("zsh")
            log_verbose "zinit plugins found in directory:"
            log_verbose "$(find "$plugins_dir" -maxdepth 1 -type d -exec basename {} \; 2>/dev/null | grep -v '^plugins$' || echo 'none')"
        else
            zsh_verify_end_time=$(date +%s)
            zsh_verify_duration=$((zsh_verify_end_time - zsh_verify_start_time))
            log_output "❌ Zsh: No plugins found in plugins directory (verified in ${zsh_verify_duration}s)"
            failed_pms+=("zsh")
        fi
    else
        zsh_verify_end_time=$(date +%s)
        zsh_verify_duration=$((zsh_verify_end_time - zsh_verify_start_time))
        log_output "❌ Zsh: zinit plugins directory not found (verified in ${zsh_verify_duration}s)"
        failed_pms+=("zsh")
    fi
    log_output ""
else
    log_verbose "zsh verification skipped (zsh missing or ~/.zinit/bin/zinit.zsh not found)"
fi

# Verify emacs (elpaca packages)
if command -v emacs >/dev/null 2>&1; then
    log_output "=== Verifying Emacs (elpaca packages) ==="

    emacs_verify_start_time=$(date +%s)
    # Check if elpaca directory exists (indicates installation attempted)
    if [[ -d "$HOME/.emacs.d/elpaca" ]]; then
        log_verbose "Running: emacs elpaca package count verification"
        # Count installed packages by checking the elpaca builds directory directly
        builds_dir="$HOME/.emacs.d/elpaca/builds"
        if [[ -d "$builds_dir" ]]; then
            package_count=$(ls -1 "$builds_dir" 2>/dev/null | wc -l | tr -d ' ')
            if [[ ${package_count:-0} -gt 0 ]]; then
                emacs_verify_end_time=$(date +%s)
                emacs_verify_duration=$((emacs_verify_end_time - emacs_verify_start_time))
                log_output "✅ Emacs: $package_count packages successfully installed (verified in ${emacs_verify_duration}s)"
                verified_pms+=("emacs")
                log_verbose "emacs elpaca packages found in builds directory: $package_count"
            else
                emacs_verify_end_time=$(date +%s)
                emacs_verify_duration=$((emacs_verify_end_time - emacs_verify_start_time))
                log_output "❌ Emacs: No packages found in builds directory (verified in ${emacs_verify_duration}s)"
                failed_pms+=("emacs")
            fi
        else
            emacs_verify_end_time=$(date +%s)
            emacs_verify_duration=$((emacs_verify_end_time - emacs_verify_start_time))
            log_output "❌ Emacs: Elpaca builds directory not found (verified in ${emacs_verify_duration}s)"
            failed_pms+=("emacs")
        fi
    else
        emacs_verify_end_time=$(date +%s)
        emacs_verify_duration=$((emacs_verify_end_time - emacs_verify_start_time))
        log_output "❌ Emacs: elpaca directory not found (~/.emacs.d/elpaca missing) (verified in ${emacs_verify_duration}s)"
        failed_pms+=("emacs")
    fi
    log_output ""
else
    log_verbose "emacs verification skipped (emacs command not found)"
fi

# Verify neovim (lazy.nvim plugins)
if command -v nvim >/dev/null 2>&1; then
    log_output "=== Verifying Neovim (lazy.nvim plugins) ==="

    nvim_verify_start_time=$(date +%s)
    # Check if lazy.nvim data directory exists
    lazy_data_dir="$HOME/.local/share/nvim/lazy"
    if [[ -d "$lazy_data_dir" ]]; then
        log_verbose "Running: nvim lazy plugin count verification"
        # Count installed plugins by checking the lazy data directory
        if plugin_dirs=$(ls -1 "$lazy_data_dir" 2>/dev/null | wc -l); then
            plugin_dirs="${plugin_dirs//[$'\r\n ']/}"
            if [[ ${plugin_dirs:-0} -gt 0 ]]; then
                nvim_verify_end_time=$(date +%s)
                nvim_verify_duration=$((nvim_verify_end_time - nvim_verify_start_time))
                log_output "✅ Neovim: $plugin_dirs plugins successfully installed (verified in ${nvim_verify_duration}s)"
                verified_pms+=("neovim")
                log_verbose "neovim lazy plugins directory count: $plugin_dirs"
                log_verbose "Installed plugins:"
                log_verbose "$(ls -1 "$lazy_data_dir" 2>/dev/null || echo 'none')"
            else
                nvim_verify_end_time=$(date +%s)
                nvim_verify_duration=$((nvim_verify_end_time - nvim_verify_start_time))
                log_output "❌ Neovim: No plugin directories found after installation (verified in ${nvim_verify_duration}s)"
                failed_pms+=("neovim")
            fi
        else
            nvim_verify_end_time=$(date +%s)
            nvim_verify_duration=$((nvim_verify_end_time - nvim_verify_start_time))
            log_output "❌ Neovim: Failed to count plugin directories (verified in ${nvim_verify_duration}s)"
            failed_pms+=("neovim")
        fi
    else
        nvim_verify_end_time=$(date +%s)
        nvim_verify_duration=$((nvim_verify_end_time - nvim_verify_start_time))
        log_output "❌ Neovim: lazy.nvim data directory not found (~/.local/share/nvim/lazy missing) (verified in ${nvim_verify_duration}s)"
        failed_pms+=("neovim")
    fi
    log_output ""
else
    log_verbose "neovim verification skipped (nvim command not found)"
fi

# Summary
log_output "Verified ${#verified_pms[@]} dev package managers"

if [[ ${#verified_pms[@]} -gt 0 ]]; then
    log_output "✅ Successfully verified: ${verified_pms[*]}"
fi

if [[ ${#failed_pms[@]} -gt 0 ]]; then
    log_output "❌ Failed verification: ${failed_pms[*]}"
    log_output ""
    log_output "💡 Troubleshooting:"
    log_output "  - Run editors manually to trigger initial package installation"
    log_output "  - Check editor configurations for syntax errors"
    log_output "  - Verify network connectivity for package downloads"
else
    log_output "🎉 All available dev package managers have packages installed!"
fi

log_output ""
log_output "📝 Verification logged to: ${LOG_FILE}"

# Exit with error code if any verifications failed
if [[ ${#failed_pms[@]} -gt 0 ]]; then
    exit 1
else
    exit 0
fi
