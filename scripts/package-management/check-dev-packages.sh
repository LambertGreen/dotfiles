#!/usr/bin/env bash
# Check dev packages wrapper with logging
# Handles application-level package managers: zsh, emacs, neovim, cargo, pipx

set -euo pipefail

# Setup
DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Configure logging
LOG_PREFIX="DEV-CHECK"
LOG_DIR="${DOTFILES_ROOT}/.logs"
LOG_FILE="${LOG_DIR}/check-dev-packages-$(date +%Y%m%d-%H%M%S).log"

# Source enhanced logging utilities
source "${DOTFILES_ROOT}/scripts/package-management/shared/logging.sh"

# Initialize log
initialize_log "check-dev-packages.sh"

# Track timing
START_TIME=$(date +%s)

# For backward compatibility with existing script
log_output() {
    log_info "$1"
}

# Function to log only to file (for verbose details)
log_verbose() {
    log_debug "$1"
}

log_section "Development Package Check"
log_info "Checking development packages for updates..."

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

# NOTE: Zsh plugins (zinit) moved to check-app-packages.sh to avoid duplication
# Check zsh (zinit plugins) - COMMENTED OUT - Now in app-packages
# if command -v zsh >/dev/null 2>&1 && [[ -f "$HOME/.zinit/bin/zinit.zsh" ]]; then
#     log_output "=== Zsh (plugins) ==="
#     checked_pms+=("zsh")

#     log_verbose "Running: zinit list in zsh context"
#     # Check if zinit has any plugins that can be updated
#     # We use a timeout since zinit commands can hang if zsh config is broken
#     if zinit_status=$(timeout 30 zsh -c 'source ~/.zinit/bin/zinit.zsh 2>/dev/null && zinit times | head -20' 2>/dev/null); then
#         if [[ -n "$zinit_status" ]]; then
#             # Count number of plugins loaded
#             plugin_count=$(echo "$zinit_status" | wc -l | tr -d ' ')
#             plugin_count="${plugin_count//[$'\r\n']/}"
#             if [[ ${plugin_count:-0} -gt 0 ]]; then
#                 log_output "Found $plugin_count zsh plugins (updates available)"
#                 updates_found=true
#                 log_verbose "zsh plugins available for update"
#                 log_verbose "$zinit_status"
#             else
#                 log_output "No zsh plugins found"
#                 log_verbose "No zsh plugins"
#             fi
#         else
#             log_output "No zsh plugins found or zinit not properly initialized"
#             log_verbose "zinit times returned empty"
#         fi
#     else
#         log_output "Error checking zsh plugin status (timeout or initialization issue)"
#         log_verbose "zsh plugin check timed out or failed"
#     fi
#     log_output ""
# else
#     log_verbose "zsh plugins not available (zsh missing or ~/.zinit/bin/zinit.zsh not found)"
# fi

# Check emacs (elpaca packages)
if command -v emacs >/dev/null 2>&1 && [[ -d "$HOME/.emacs.d/elpaca" ]]; then
    log_subsection "Emacs Packages"
    checked_pms+=("emacs")

    log_verbose "Checking elpaca packages directory"
    # Check elpaca packages by looking at the builds directory
    if [[ -d "$HOME/.emacs.d/elpaca/builds" ]]; then
        if package_list=$(ls -1 "$HOME/.emacs.d/elpaca/builds" 2>/dev/null); then
            if [[ -n "$package_list" ]]; then
                package_count=$(echo "$package_list" | wc -l | tr -d ' ')
                log_output "Found $package_count emacs packages:"
                # Show first 10 packages
                formatted_packages=$(echo "$package_list" | sed 's/^/  - /' | head -10)
                log_output "$formatted_packages"
                if [[ $package_count -gt 10 ]]; then
                    log_output "  ... and $((package_count - 10)) more packages"
                fi
                updates_found=true
                log_verbose "emacs packages (updates may be available - check in Emacs)"
            else
                log_output "No emacs packages found"
                log_verbose "No emacs packages in builds directory"
            fi
        else
            log_output "Cannot read emacs elpaca builds directory"
            log_verbose "ls command failed on ~/.emacs.d/elpaca/builds"
        fi
    else
        log_output "Emacs elpaca builds directory not found"
        log_verbose "Expected directory: ~/.emacs.d/elpaca/builds"
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
        log_subsection "Neovim Plugins"
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
    log_subsection "Cargo (Rust Tools)"
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
    log_subsection "Pipx (Python Tools)"
    checked_pms+=("pipx")

    log_verbose "Running: pipx list --short"
    # Check if pipx has installed packages and show their versions
    if pipx_packages=$(pipx list --short 2>/dev/null); then
        if [[ -n "$pipx_packages" ]]; then
            package_count=$(echo "$pipx_packages" | wc -l | tr -d ' ')
            log_output "Found $package_count pipx tools:"
            log_output "$pipx_packages"

            # Check for outdated packages
            log_verbose "Checking for outdated pipx packages"
            if outdated_pipx=$(pipx list --short 2>/dev/null); then
                updates_found=true
                log_verbose "pipx packages (updates may be available - run pipx upgrade-all)"
            fi
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
log_section "Check Summary"

if [[ ${#checked_pms[@]} -eq 0 ]]; then
    log_warn "No dev package managers found"
    log_debug "No dev package managers detected on this system"
else
    log_success "Checked dev package managers: ${checked_pms[*]}"
    if [[ "$updates_found" == true ]]; then
        log_warn "Updates available - run 'just upgrade-dev-packages' to install"
    else
        log_success "All dev packages are up to date"
    fi
fi

log_duration "${START_TIME}"
finalize_log "SUCCESS"

log_info "Check session logged to: ${LOG_FILE}"
