#!/usr/bin/env bash
# Simple brew lock cleanup for package management scripts
# Handles the common case of git fsmonitor processes holding brew locks

set -euo pipefail

# Check if brew lock exists and handle it
cleanup_brew_locks_if_needed() {
    local brew_prefix
    if command -v brew >/dev/null 2>&1; then
        brew_prefix=$(brew --prefix)
    else
        return 0
    fi

    local locks_dir="${brew_prefix}/var/homebrew/locks"

    # Check if locks exist
    if [[ ! -d "$locks_dir" ]] || [[ -z "$(ls -A "$locks_dir" 2>/dev/null)" ]]; then
        return 0  # No locks to clean
    fi

    # Check if any processes are holding the locks
    local lock_holders_found=false
    for lock_file in "$locks_dir"/*; do
        if [[ -f "$lock_file" ]] && lsof "$lock_file" >/dev/null 2>&1; then
            lock_holders_found=true
            break
        fi
    done

    if [[ "$lock_holders_found" == "true" ]]; then
        log_warn "Brew lock files are being held by other processes"
        log_info "Attempting to clean up brew locks..."

        # Try to remove the lock files (they're often just empty files)
        local removed_count=0
        for lock_file in "$locks_dir"/*; do
            if [[ -f "$lock_file" ]]; then
                if rm "$lock_file" 2>/dev/null; then
                    log_debug "Removed lock file: $(basename "$lock_file")"
                    ((removed_count++))
                fi
            fi
        done

        if [[ $removed_count -gt 0 ]]; then
            log_success "Cleaned up $removed_count brew lock files"
            # Give a moment for any processes to notice
            sleep 1
        else
            log_warn "Could not remove lock files - they may be actively locked"
        fi
    fi
}

# Export function for use in other scripts
export -f cleanup_brew_locks_if_needed
