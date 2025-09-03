#!/usr/bin/env bash
# Initialize dev package managers by triggering their first-time setup
# This is different from updating - this handles the initial package installation

set -euo pipefail

# Setup
DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Configure logging
LOG_PREFIX="DEV-INIT"
LOG_DIR="${DOTFILES_ROOT}/.logs"
LOG_FILE="${LOG_DIR}/init-dev-packages-$(date +%Y%m%d-%H%M%S).log"

# Source enhanced logging utilities
source "${DOTFILES_ROOT}/scripts/package-management/shared/logging.sh"

# Initialize log
initialize_log "init-dev-packages.sh"

# Track timing
START_TIME=$(date +%s)

log_section "Development Package Manager Initialization"
log_info "Starting dev package manager initialization..."

# Load configuration if available
if [[ -f ~/.dotfiles.env ]]; then
    # shellcheck source=/dev/null
    source ~/.dotfiles.env
    log_debug "Loaded configuration from ~/.dotfiles.env"
    log_debug "DOTFILES_PLATFORM: ${DOTFILES_PLATFORM:-'not set'}"
    log_debug "DOTFILES_MACHINE_CLASS: ${DOTFILES_MACHINE_CLASS:-'not set'}"
else
    log_debug "No ~/.dotfiles.env found"
fi

# Track initialization results
initialized_pms=()
failed_pms=()

# Initialize zsh (zinit plugins)
if command -v zsh >/dev/null 2>&1; then
    log_output "=== Initializing Zsh (zinit plugins) ==="

    zsh_start_time=$(date +%s)

    # First, trigger the initial shell load (which may install zinit via timeout)
    log_verbose "[INFO] Running initial zsh load to trigger plugin manager setup"
    timeout 30 zsh -l -i -c 'exit' 2>&1 | tee -a "${LOG_FILE}" || true

    # Wait for zinit to fully initialize after installation
    log_verbose "[INFO] Waiting for zinit to initialize..."
    sleep 3

    # Check actual zinit status instead of using shell inference
    log_verbose "[INFO] Checking zinit installation and plugin status"

    # Try to get plugin count directly (more reliable than command -v zinit)
    if plugin_count=$(zsh -l -i -c 'zinit list' 2>/dev/null | wc -l | tr -d ' ' 2>/dev/null); then
        if [[ ${plugin_count:-0} -gt 0 ]]; then
            zsh_end_time=$(date +%s)
            zsh_duration=$((zsh_end_time - zsh_start_time))
            log_output "[SUCCESS] Zsh plugin initialization completed - ${plugin_count} plugins loaded (${zsh_duration}s)"
            initialized_pms+=("zsh")
        else
            # Check if zinit directory exists as fallback
            if [[ -d "$HOME/.zinit" ]]; then
                zsh_end_time=$(date +%s)
                zsh_duration=$((zsh_end_time - zsh_start_time))
                log_output "[INFO] Zinit installed but no plugins listed yet (${zsh_duration}s)"
                initialized_pms+=("zsh")
            else
                zsh_end_time=$(date +%s)
                zsh_duration=$((zsh_end_time - zsh_start_time))
                log_output "[ERROR] Zinit installed but no plugins loaded (${zsh_duration}s)"
                failed_pms+=("zsh")
            fi
        fi
    else
        # Check if zinit directory exists as fallback
        if [[ -d "$HOME/.zinit" ]]; then
            zsh_end_time=$(date +%s)
            zsh_duration=$((zsh_end_time - zsh_start_time))
            log_output "[INFO] Zinit installed but cannot query plugin status (${zsh_duration}s)"
            initialized_pms+=("zsh")
        else
            zsh_end_time=$(date +%s)
            zsh_duration=$((zsh_end_time - zsh_start_time))
            log_output "[ERROR] Zinit not installed or not available (${zsh_duration}s)"
            failed_pms+=("zsh")
        fi
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
            log_output "[SUCCESS] Emacs package initialization completed (${emacs_duration}s)"
            initialized_pms+=("emacs")
        else
            emacs_end_time=$(date +%s)
            emacs_duration=$((emacs_end_time - emacs_start_time))
            log_output "[ERROR] Emacs package initialization failed (${emacs_duration}s)"
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
            log_output "[SUCCESS] Emacs package initialization completed (${emacs_duration}s)"
            initialized_pms+=("emacs")
        else
            emacs_end_time=$(date +%s)
            emacs_duration=$((emacs_end_time - emacs_start_time))
            log_output "[ERROR] Emacs package initialization failed (${emacs_duration}s)"
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
        log_output "[SUCCESS] Neovim plugin initialization completed (${nvim_duration}s)"
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
    log_output "[SUCCESS] Successfully initialized: ${initialized_pms[*]}"
fi

if [[ ${#failed_pms[@]} -gt 0 ]]; then
    log_output "[ERROR] Failed initialization: ${failed_pms[*]}"
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
