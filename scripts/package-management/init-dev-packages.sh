#!/usr/bin/env bash
# Initialize dev package managers by triggering their first-time setup
# This is different from updating - this handles the initial package installation

set -euo pipefail

# Set up logging
DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_DIR="${DOTFILES_ROOT}/logs"
LOG_FILE="${LOG_DIR}/init-dev-packages-$(date +%Y%m%d-%H%M%S).log"

# Create log directory if it doesn't exist
mkdir -p "${LOG_DIR}"

# Initialize log file with header
{
    echo "Initialize Dev Packages Log"
    echo "=========================="
    echo "Date: $(date)"
    echo "Machine: $(hostname 2>/dev/null || echo 'unknown')"
    echo "User: ${USER:-$(whoami)}"
    echo "Script: $0 $*"
    echo "=========================="
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

log_output "🚀 Dev Package Manager Initialization"
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

# Track initialization results
initialized_pms=()
failed_pms=()

# Initialize zsh (zinit plugins)
if command -v zsh >/dev/null 2>&1 && [[ -f "$HOME/.zinit/bin/zinit.zsh" ]]; then
    log_output "=== Initializing Zsh (zinit plugins) ==="
    
    log_verbose "Running: zinit update --all to trigger initial plugin installation"
    if timeout 300 zsh -c 'source ~/.zinit/bin/zinit.zsh 2>/dev/null && zinit update --all' 2>&1 | tee -a "${LOG_FILE}"; then
        log_output "✅ Zsh plugin initialization completed"
        # Clean up and compile
        log_verbose "Running: zinit cclear for cleanup and compilation"
        timeout 120 zsh -c 'source ~/.zinit/bin/zinit.zsh 2>/dev/null && zinit cclear' 2>&1 | tee -a "${LOG_FILE}" || true
        initialized_pms+=("zsh")
    else
        log_output "❌ Zsh plugin initialization failed"
        failed_pms+=("zsh")
    fi
    log_output ""
else
    log_verbose "zsh initialization skipped (zsh missing or ~/.zinit/bin/zinit.zsh not found)"
fi

# Initialize emacs (elpaca packages)
if command -v emacs >/dev/null 2>&1; then
    log_output "=== Initializing Emacs (elpaca packages) ==="
    
    # Check if elpaca is already installed
    if [[ -d "$HOME/.emacs.d/elpaca" ]]; then
        log_verbose "Running: emacs with DOTFILES_EMACS_UPDATE environment variable for package updates"
        # Elpaca already exists, use update mode
        if timeout 600 env DOTFILES_EMACS_UPDATE=1 emacs --batch -l ~/.emacs.d/init.el 2>&1 | tee -a "${LOG_FILE}"; then
            log_output "✅ Emacs package initialization completed"
            initialized_pms+=("emacs")
        else
            log_output "❌ Emacs package initialization failed"
            failed_pms+=("emacs")
        fi
    else
        log_verbose "Running: emacs initial bootstrap (elpaca will be installed and packages downloaded)"
        # First time setup - run emacs to bootstrap elpaca, then use batch mode to ensure packages are installed
        # Step 1: Bootstrap elpaca (this needs to be done interactively-ish)
        if timeout 300 emacs --batch --eval "(progn (load-file \"~/.emacs.d/config/init-package-manager.el\") (message \"Elpaca bootstrap complete\"))" 2>&1 | tee -a "${LOG_FILE}"; then
            # Step 2: Now load full config to install all packages
            if timeout 300 emacs --batch -l ~/.emacs.d/init.el --eval "(message \"Package installation complete\")" 2>&1 | tee -a "${LOG_FILE}"; then
                log_output "✅ Emacs package initialization completed"
                initialized_pms+=("emacs")
            else
                log_output "❌ Emacs package installation failed"
                failed_pms+=("emacs")
            fi
        else
            log_output "❌ Emacs elpaca bootstrap failed"
            failed_pms+=("emacs")
        fi
    fi
    log_output ""
else
    log_verbose "emacs initialization skipped (emacs command not found)"
fi

# Initialize neovim (lazy.nvim plugins)
if command -v nvim >/dev/null 2>&1; then
    log_output "=== Initializing Neovim (lazy.nvim plugins) ==="
    
    log_verbose "Running: nvim headless with Lazy sync to trigger plugin installation"
    # Use Lazy! sync which forces a full synchronization
    if timeout 600 nvim --headless "+Lazy! sync" +qa 2>&1 | tee -a "${LOG_FILE}"; then
        log_output "✅ Neovim plugin initialization completed"
        initialized_pms+=("neovim")
    else
        log_output "❌ Neovim plugin initialization failed"
        failed_pms+=("neovim")
    fi
    log_output ""
else
    log_verbose "neovim initialization skipped (nvim command not found)"
fi

# Summary
log_output "📊 Dev Package Initialization Summary"
log_output "===================================="

if [[ ${#initialized_pms[@]} -gt 0 ]]; then
    log_output "✅ Successfully initialized: ${initialized_pms[*]}"
fi

if [[ ${#failed_pms[@]} -gt 0 ]]; then
    log_output "❌ Failed initialization: ${failed_pms[*]}"
else
    log_output "🎉 All available dev package managers initialized successfully!"
fi

log_output ""
log_output "💡 Next steps:"
log_output "  just verify-dev-package-install  - Verify packages were actually installed"
log_output "  just check-dev-packages         - Check for any available updates"

log_output ""
log_output "📝 Initialization logged to: ${LOG_FILE}"

# Exit with error code if any initializations failed
if [[ ${#failed_pms[@]} -gt 0 ]]; then
    exit 1
else
    exit 0
fi