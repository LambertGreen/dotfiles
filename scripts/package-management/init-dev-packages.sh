#!/usr/bin/env bash
# Initialize dev package managers by triggering their first-time setup
# This is different from updating - this handles the initial package installation

set -euo pipefail

# Set up logging
DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_DIR="${DOTFILES_ROOT}/.logs"
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
if command -v zsh >/dev/null 2>&1; then
    log_output "=== Initializing Zsh (zinit plugins) ==="
    
    zsh_start_time=$(date +%s)
    
    # First, trigger the initial shell load (which may install zinit via timeout)
    log_verbose "Running: initial zsh load to trigger plugin manager setup"
    timeout 30 zsh -l -i -c 'exit' 2>&1 | tee -a "${LOG_FILE}" || true
    
    # Now use the dotfiles API to wait for ready state
    log_verbose "Running: await shell ready using dotfiles API"
    if timeout 60 zsh -l -i -c 'source ~/.zshrc && lgreen_await_shell_ready 45' 2>&1 | tee -a "${LOG_FILE}"; then
        # Shell is ready, ensure plugins are updated
        log_verbose "Running: ensure plugins updated using dotfiles API"
        if timeout 300 zsh -l -i -c 'source ~/.zshrc && lgreen_ensure_plugins_updated' 2>&1 | tee -a "${LOG_FILE}"; then
            zsh_end_time=$(date +%s)
            zsh_duration=$((zsh_end_time - zsh_start_time))
            log_output "✅ Zsh plugin initialization completed (${zsh_duration}s)"
            initialized_pms+=("zsh")
        else
            zsh_end_time=$(date +%s)
            zsh_duration=$((zsh_end_time - zsh_start_time))
            log_output "⚠️ Zsh plugins may not be fully updated (${zsh_duration}s)"
            initialized_pms+=("zsh")  # Still consider it initialized if shell is ready
        fi
    else
        zsh_end_time=$(date +%s)
        zsh_duration=$((zsh_end_time - zsh_start_time))
        log_output "❌ Zsh plugin initialization failed - shell not ready (${zsh_duration}s)"
        failed_pms+=("zsh")
    fi
    log_output ""
else
    log_verbose "zsh initialization skipped (zsh not found)"
fi

# Initialize emacs (elpaca packages)
if command -v emacs >/dev/null 2>&1; then
    log_output "=== Initializing Emacs (elpaca packages) ==="
    
    emacs_start_time=$(date +%s)
    # Check if elpaca is already installed
    if [[ -d "$HOME/.emacs.d/elpaca" ]]; then
        log_verbose "Running: emacs with DOTFILES_EMACS_UPDATE environment variable for package updates"
        # Elpaca already exists, use update mode
        if timeout 600 env DOTFILES_EMACS_UPDATE=1 emacs --batch -l ~/.emacs.d/init.el 2>&1 | tee -a "${LOG_FILE}"; then
            emacs_end_time=$(date +%s)
            emacs_duration=$((emacs_end_time - emacs_start_time))
            log_output "✅ Emacs package initialization completed (${emacs_duration}s)"
            initialized_pms+=("emacs")
        else
            emacs_end_time=$(date +%s)
            emacs_duration=$((emacs_end_time - emacs_start_time))
            log_output "❌ Emacs package initialization failed (${emacs_duration}s)"
            failed_pms+=("emacs")
        fi
    else
        log_verbose "Running: emacs initial bootstrap (elpaca will be installed and packages downloaded)"
        # First time setup - load full config and wait for all packages to install
        # Use elpaca-log-buffer and progress reporting for better visibility
        if timeout 900 emacs --batch --eval "(progn 
            (load-file \"~/.emacs.d/init.el\") 
            (message \"Loaded init.el, waiting for packages...\")
            
            ;; Enable more verbose elpaca output
            (setq elpaca-verbosity 2)
            (setq elpaca-log-level 'debug)
            
            ;; Add progress tracking
            (defvar package-install-start-time (current-time))
            (defun log-package-progress ()
              (let ((elapsed (float-time (time-subtract (current-time) package-install-start-time))))
                (message \"[PROGRESS] Elapsed: %.0fs, Queue size: %d\" 
                         elapsed (length elpaca--queues))))
            
            ;; Set up periodic progress reporting
            (run-with-timer 30 30 'log-package-progress)
            
            ;; Wait for packages with timeout handling
            (let ((max-wait-time 840)) ;; 14 minutes
              (condition-case err
                (with-timeout (max-wait-time 
                              (message \"[TIMEOUT] Package installation exceeded %d seconds\" max-wait-time)
                              (message \"[DEBUG] Current elpaca queue status:\")
                              (dolist (item elpaca--queues)
                                (message \"[DEBUG] Queue item: %s\" item))
                              (error \"Package installation timeout\"))
                  (elpaca-wait)
                  (message \"All packages installed successfully!\"))
                (error 
                 (message \"[ERROR] Package installation failed: %s\" err)
                 (when (get-buffer elpaca-log-buffer-name)
                   (message \"[DEBUG] Elpaca log buffer contents:\")
                   (with-current-buffer (get-buffer elpaca-log-buffer-name)
                     (message \"%s\" (buffer-string))))
                 (signal (car err) (cdr err))))))" 2>&1 | tee -a "${LOG_FILE}"; then
            emacs_end_time=$(date +%s)
            emacs_duration=$((emacs_end_time - emacs_start_time))
            log_output "✅ Emacs package initialization completed (${emacs_duration}s)"
            initialized_pms+=("emacs")
        else
            emacs_end_time=$(date +%s)
            emacs_duration=$((emacs_end_time - emacs_start_time))
            log_output "❌ Emacs package initialization failed (${emacs_duration}s)"
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
    
    nvim_start_time=$(date +%s)
    log_verbose "Running: nvim headless with Lazy sync to trigger plugin installation"
    # Use Lazy! sync which forces a full synchronization
    if timeout 600 nvim --headless "+Lazy! sync" +qa 2>&1 | tee -a "${LOG_FILE}"; then
        nvim_end_time=$(date +%s)
        nvim_duration=$((nvim_end_time - nvim_start_time))
        log_output "✅ Neovim plugin initialization completed (${nvim_duration}s)"
        initialized_pms+=("neovim")
    else
        nvim_end_time=$(date +%s)
        nvim_duration=$((nvim_end_time - nvim_start_time))
        log_output "❌ Neovim plugin initialization failed (${nvim_duration}s)"
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