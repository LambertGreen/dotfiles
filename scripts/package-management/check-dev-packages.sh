#!/usr/bin/env bash
# Check dev packages wrapper with logging
# Handles application-level package managers: zsh, emacs, neovim, cargo, pipx

set -euo pipefail

# Set up logging
DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_DIR="${DOTFILES_ROOT}/logs"
LOG_FILE="${LOG_DIR}/check-dev-packages-$(date +%Y%m%d-%H%M%S).log"

# Create log directory if it doesn't exist
mkdir -p "${LOG_DIR}"

# Initialize log file with header
{
    echo "Check Dev Packages Log"
    echo "======================"
    echo "Date: $(date)"
    echo "Machine: $(hostname 2>/dev/null || echo 'unknown')"
    echo "User: ${USER:-$(whoami)}"
    echo "Script: $0 $*"
    echo "======================"
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

log_output "🔍 Checking for updates across all dev package managers..."
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

# Track what package managers we check
checked_pms=()
updates_found=false

# Check zsh (zinit plugins)
if command -v zsh >/dev/null 2>&1 && [[ -f "$HOME/.zinit/bin/zinit.zsh" ]]; then
    log_output "=== Zsh (plugins) ==="
    checked_pms+=("zsh")
    
    log_verbose "Running: zinit list in zsh context"
    # Check if zinit has any plugins that can be updated
    # We use a timeout since zinit commands can hang if zsh config is broken
    if zinit_status=$(timeout 30 zsh -c 'source ~/.zinit/bin/zinit.zsh 2>/dev/null && zinit times | head -20' 2>/dev/null); then
        if [[ -n "$zinit_status" ]]; then
            # Count number of plugins loaded
            plugin_count=$(echo "$zinit_status" | wc -l | tr -d ' ')
            plugin_count="${plugin_count//[$'\r\n']/}"
            if [[ ${plugin_count:-0} -gt 0 ]]; then
                log_output "Found $plugin_count zsh plugins (updates available)"
                updates_found=true
                log_verbose "zsh plugins available for update"
                log_verbose "$zinit_status"
            else
                log_output "No zsh plugins found"
                log_verbose "No zsh plugins"
            fi
        else
            log_output "No zsh plugins found or zinit not properly initialized"
            log_verbose "zinit times returned empty"
        fi
    else
        log_output "Error checking zsh plugin status (timeout or initialization issue)"
        log_verbose "zsh plugin check timed out or failed"
    fi
    log_output ""
else
    log_verbose "zsh plugins not available (zsh missing or ~/.zinit/bin/zinit.zsh not found)"
fi

# Check emacs (elpaca packages)
if command -v emacs >/dev/null 2>&1 && [[ -d "$HOME/.emacs.d/elpaca" ]]; then
    log_output "=== Emacs (packages) ==="
    checked_pms+=("emacs")
    
    log_verbose "Running: emacs elpaca status check"
    # Check if elpaca has packages that can be updated
    if emacs_status=$(timeout 60 emacs --batch --eval "(progn (require 'elpaca) (message \"%d packages installed\" (length (elpaca--queued))))" 2>/dev/null | grep "packages installed" || echo ""); then
        if [[ -n "$emacs_status" ]]; then
            package_count=$(echo "$emacs_status" | grep -o '[0-9]\+' | head -1)
            if [[ ${package_count:-0} -gt 0 ]]; then
                log_output "Found $package_count emacs packages (updates available)"
                updates_found=true
                log_verbose "emacs packages available for update"
            else
                log_output "No emacs packages found"
                log_verbose "No emacs packages"
            fi
        else
            log_output "No emacs packages found or elpaca not properly configured"
            log_verbose "elpaca check returned empty"
        fi
    else
        log_output "Error checking emacs package status (timeout or configuration issue)"
        log_verbose "emacs package check timed out or failed"
    fi
    log_output ""
else
    log_verbose "emacs packages not available (emacs missing or ~/.emacs.d/elpaca not found)"
fi

# Check neovim (lazy.nvim plugins)
if command -v nvim >/dev/null 2>&1; then
    # Check if lazy.nvim is being used
    lazy_config_found=false
    
    # Check common lazy.nvim config locations
    for config_path in "$HOME/.config/nvim/lua/config/lazy.lua" "$HOME/.config/nvim/init.lua" "$HOME/.config/nvim-lazy"; do
        if [[ -f "$config_path" ]] && grep -q "lazy" "$config_path" 2>/dev/null; then
            lazy_config_found=true
            break
        fi
    done
    
    if [[ "$lazy_config_found" == true ]]; then
        log_output "=== Neovim (plugins) ==="
        checked_pms+=("neovim")
        
        log_verbose "Running: nvim lazy status check"
        # Check if lazy.nvim has plugins that can be updated
        if nvim_status=$(timeout 30 nvim --headless -c "lua print(#require('lazy').plugins())" -c "qa" 2>/dev/null || echo ""); then
            if [[ -n "$nvim_status" ]] && [[ "$nvim_status" =~ ^[0-9]+$ ]]; then
                if [[ ${nvim_status:-0} -gt 0 ]]; then
                    log_output "Found $nvim_status neovim plugins (updates available)"
                    updates_found=true
                    log_verbose "neovim plugins available for update"
                else
                    log_output "No neovim plugins found"
                    log_verbose "No neovim plugins"
                fi
            else
                log_output "No neovim plugins found or lazy.nvim not properly configured"
                log_verbose "lazy.nvim check returned: $nvim_status"
            fi
        else
            log_output "Error checking neovim plugin status (timeout or configuration issue)"
            log_verbose "neovim plugin check timed out or failed"
        fi
        log_output ""
    else
        log_verbose "neovim plugins not available (lazy.nvim config not found)"
    fi
else
    log_verbose "neovim not available"
fi

# Check cargo (Rust tools)
if command -v cargo >/dev/null 2>&1 && [[ -d "$HOME/.cargo/bin" ]]; then
    log_output "=== Cargo (Rust tools) ==="
    checked_pms+=("cargo")
    
    log_verbose "Running: cargo install --list"
    # Check if cargo has installed tools
    if cargo_list=$(cargo install --list 2>/dev/null | grep -c '^[a-zA-Z]' || echo "0"); then
        if [[ ${cargo_list:-0} -gt 0 ]]; then
            log_output "Found $cargo_list cargo tools (updates available via cargo-update)"
            updates_found=true
            log_verbose "cargo tools available for update"
        else
            log_output "No cargo tools installed"
            log_verbose "No cargo tools"
        fi
    else
        log_output "Error checking cargo tools"
        log_verbose "cargo install --list failed"
    fi
    log_output ""
else
    log_verbose "cargo not available or ~/.cargo/bin not found"
fi

# Check pipx (Python CLI tools)
if command -v pipx >/dev/null 2>&1; then
    log_output "=== Pipx (Python tools) ==="
    checked_pms+=("pipx")
    
    log_verbose "Running: pipx list"
    # Check if pipx has installed packages
    if pipx_list=$(pipx list --short 2>/dev/null | wc -l | tr -d ' '); then
        pipx_list="${pipx_list//[$'\r\n']/}"
        if [[ ${pipx_list:-0} -gt 0 ]]; then
            log_output "Found $pipx_list pipx tools (updates available)"
            updates_found=true
            log_verbose "pipx tools available for update"
        else
            log_output "No pipx tools installed"
            log_verbose "No pipx tools"
        fi
    else
        log_output "Error checking pipx tools"
        log_verbose "pipx list failed"
    fi
    log_output ""
else
    log_verbose "pipx not available"
fi

# Summary
log_output "📊 Dev Package Update Check Summary"
log_output "==================================="

if [[ ${#checked_pms[@]} -eq 0 ]]; then
    log_output "⚠️  No dev package managers found"
else
    log_output "✅ Checked dev package managers: ${checked_pms[*]}"
    
    if [[ "$updates_found" == true ]]; then
        log_output "📦 Updates available - run 'just upgrade-dev-packages' to install"
    else
        log_output "✅ All dev packages are up to date"
    fi
fi

log_output ""
log_output "📝 Check dev packages session logged to: ${LOG_FILE}"

# Log final status to file
{
    echo ""
    echo "=== CHECK DEV PACKAGES COMPLETION ==="
    echo "Dev package managers checked: ${checked_pms[*]:-none}"
    echo "Updates found: $updates_found"
    echo "DOTFILES_PLATFORM: ${DOTFILES_PLATFORM:-'not set'}"
    echo "DOTFILES_MACHINE_CLASS: ${DOTFILES_MACHINE_CLASS:-'not set'}"
    echo "======================================"
    echo ""
    echo "Check dev packages completed at: $(date)"
} >> "${LOG_FILE}"