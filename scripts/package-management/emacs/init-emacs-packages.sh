#!/usr/bin/env bash
# Emacs package initialization script

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
LOG_DIR="${DOTFILES_ROOT}/logs"

# Load shared utilities
source "${DOTFILES_ROOT}/scripts/package-management/shared/common.sh"
source "${DOTFILES_ROOT}/scripts/package-management/shared/package-utils.sh"

# Load machine class configuration
if [[ -f "${HOME}/.dotfiles.env" ]]; then
    source "${HOME}/.dotfiles.env"
else
    log_error "Machine class not configured. Run: ./package-management/scripts/configure-machine-class.sh"
    exit 1
fi

# Initialize tracking
initialize_tracking_arrays

# Emacs package initialization function
init_emacs_packages() {
    local emacs_dir="${HOME}/.emacs.d"
    
    if [[ ! -d "$emacs_dir" ]]; then
        log_error "Emacs config directory not found: $emacs_dir"
        return 1
    fi
    
    log_info "Checking if emacs packages already installed..."
    local elpaca_dir="${emacs_dir}/elpaca"
    
    if [[ -d "$elpaca_dir" ]] && [[ -n "$(ls -A "$elpaca_dir/builds" 2>/dev/null)" ]]; then
        log_info "Emacs packages already installed, skipping initial setup"
        return 0
    fi
    
    log_info "Running emacs initial bootstrap (elpaca will be installed and packages downloaded)"
    
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
             (signal (car err) (cdr err))))))" 2>&1; then
        log_success "Emacs package initialization completed"
        return 0
    else
        log_error "Emacs package initialization failed"
        return 1
    fi
}

# Main execution
main() {
    log_output "Emacs Package Initialization"
    log_output "============================"
    log_output "Machine class: ${DOTFILES_MACHINE_CLASS}"
    log_output ""
    
    execute_package_manager "emacs" "init_emacs_packages"
    
    print_summary "Emacs Package Initialization"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi