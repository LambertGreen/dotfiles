#!/usr/bin/env bash
# Brew lock detection and cleanup utilities
# Handles orphaned locks and conflicting processes

set -euo pipefail

# Get the brew prefix (handles different architectures)
get_brew_prefix() {
    if command -v brew >/dev/null 2>&1; then
        brew --prefix
    elif [[ -d "/opt/homebrew" ]]; then
        echo "/opt/homebrew"
    elif [[ -d "/usr/local" ]]; then
        echo "/usr/local"
    else
        echo ""
    fi
}

# Check if brew lock files exist
check_brew_locks() {
    local brew_prefix
    brew_prefix=$(get_brew_prefix)

    if [[ -z "$brew_prefix" ]]; then
        return 1
    fi

    local locks_dir="${brew_prefix}/var/homebrew/locks"
    if [[ -d "$locks_dir" ]] && [[ -n "$(ls -A "$locks_dir" 2>/dev/null)" ]]; then
        return 0  # Locks exist
    else
        return 1  # No locks
    fi
}

# List current brew lock files with details
list_brew_locks() {
    local brew_prefix
    brew_prefix=$(get_brew_prefix)

    if [[ -z "$brew_prefix" ]]; then
        echo "Homebrew not found"
        return 1
    fi

    local locks_dir="${brew_prefix}/var/homebrew/locks"
    if [[ -d "$locks_dir" ]]; then
        echo "Lock files in ${locks_dir}:"
        ls -la "$locks_dir" 2>/dev/null || echo "  (empty)"
    else
        echo "Lock directory doesn't exist: ${locks_dir}"
        return 1
    fi
}

# Find processes holding brew lock files
find_lock_holders() {
    local brew_prefix
    brew_prefix=$(get_brew_prefix)

    if [[ -z "$brew_prefix" ]]; then
        return 1
    fi

    local locks_dir="${brew_prefix}/var/homebrew/locks"
    local lock_holders=()

    if [[ -d "$locks_dir" ]]; then
        for lock_file in "$locks_dir"/*; do
            if [[ -f "$lock_file" ]]; then
                local holders
                if holders=$(lsof "$lock_file" 2>/dev/null); then
                    echo "Lock file: $(basename "$lock_file")"
                    echo "$holders"
                    echo ""
                    # Extract PIDs for later use
                    local pids
                    pids=$(echo "$holders" | tail -n +2 | awk '{print $2}')
                    lock_holders+=($pids)
                fi
            fi
        done
    fi

    if [[ ${#lock_holders[@]} -gt 0 ]]; then
        echo "Processes holding locks: ${lock_holders[*]}"
        return 0
    else
        return 1
    fi
}

# Check if locks are stale (no processes holding them)
are_locks_stale() {
    if check_brew_locks; then
        # If we can't find any processes holding locks, they're stale
        ! find_lock_holders >/dev/null 2>&1
    else
        return 1  # No locks to be stale
    fi
}

# Kill processes holding brew locks (with confirmation)
kill_lock_holders() {
    local force_kill="${1:-false}"
    local brew_prefix
    brew_prefix=$(get_brew_prefix)

    if [[ -z "$brew_prefix" ]]; then
        echo "Error: Homebrew not found"
        return 1
    fi

    local locks_dir="${brew_prefix}/var/homebrew/locks"
    local pids_to_kill=()

    if [[ -d "$locks_dir" ]]; then
        for lock_file in "$locks_dir"/*; do
            if [[ -f "$lock_file" ]]; then
                local holders
                if holders=$(lsof "$lock_file" 2>/dev/null); then
                    local pids
                    pids=$(echo "$holders" | tail -n +2 | awk '{print $2}')
                    for pid in $pids; do
                        pids_to_kill+=("$pid")
                    done
                fi
            fi
        done
    fi

    if [[ ${#pids_to_kill[@]} -eq 0 ]]; then
        echo "No processes holding brew locks"
        return 0
    fi

    echo "Found processes holding brew locks:"
    for pid in "${pids_to_kill[@]}"; do
        ps -p "$pid" 2>/dev/null || echo "PID $pid (process may have exited)"
    done

    if [[ "$force_kill" != "true" ]]; then
        echo ""
        echo "⚠️  This will terminate the processes holding brew locks."
        read -p "Continue? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Cancelled"
            return 1
        fi
    fi

    local killed_count=0
    for pid in "${pids_to_kill[@]}"; do
        if kill "$pid" 2>/dev/null; then
            echo "Killed process $pid"
            ((killed_count++))
        else
            echo "Failed to kill process $pid (may have already exited)"
        fi
    done

    echo "Killed $killed_count processes"
    return 0
}

# Remove stale brew lock files
remove_stale_locks() {
    local force_remove="${1:-false}"
    local brew_prefix
    brew_prefix=$(get_brew_prefix)

    if [[ -z "$brew_prefix" ]]; then
        echo "Error: Homebrew not found"
        return 1
    fi

    local locks_dir="${brew_prefix}/var/homebrew/locks"

    if ! check_brew_locks; then
        echo "No brew lock files found"
        return 0
    fi

    # Check if locks are actually stale
    if ! are_locks_stale && [[ "$force_remove" != "true" ]]; then
        echo "Lock files are not stale (processes are holding them)"
        echo "Use 'kill_lock_holders' first, or use force_remove=true"
        return 1
    fi

    if [[ "$force_remove" != "true" ]]; then
        echo "Found stale brew lock files:"
        list_brew_locks
        echo ""
        read -p "Remove all lock files? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Cancelled"
            return 1
        fi
    fi

    local removed_count=0
    if [[ -d "$locks_dir" ]]; then
        for lock_file in "$locks_dir"/*; do
            if [[ -f "$lock_file" ]]; then
                if rm "$lock_file" 2>/dev/null; then
                    echo "Removed: $(basename "$lock_file")"
                    ((removed_count++))
                else
                    echo "Failed to remove: $(basename "$lock_file")"
                fi
            fi
        done
    fi

    echo "Removed $removed_count lock files"
    return 0
}

# Comprehensive lock cleanup (kills processes and removes locks)
cleanup_brew_locks() {
    local force="${1:-false}"

    echo "🔍 Checking for brew lock issues..."

    if ! check_brew_locks; then
        echo "✅ No brew locks found"
        return 0
    fi

    echo "Found brew locks:"
    list_brew_locks
    echo ""

    # Try to find what's holding the locks
    echo "🕵️ Checking for processes holding locks..."
    if find_lock_holders; then
        echo ""
        echo "🔄 Killing processes holding brew locks..."
        if kill_lock_holders "$force"; then
            # Wait a moment for processes to die
            sleep 2
        else
            if [[ "$force" != "true" ]]; then
                echo "Lock cleanup cancelled"
                return 1
            fi
        fi
    fi

    echo ""
    echo "🧹 Removing lock files..."
    remove_stale_locks "$force"

    echo ""
    if check_brew_locks; then
        echo "⚠️  Some locks may still exist"
        list_brew_locks
        return 1
    else
        echo "✅ All brew locks cleaned up"
        return 0
    fi
}

# Check if brew update would be blocked by locks
would_brew_be_blocked() {
    if check_brew_locks; then
        echo "Brew would be blocked by existing locks"
        return 0
    else
        echo "Brew should work normally"
        return 1
    fi
}

# Export functions for use in other scripts
export -f get_brew_prefix
export -f check_brew_locks
export -f list_brew_locks
export -f find_lock_holders
export -f are_locks_stale
export -f kill_lock_holders
export -f remove_stale_locks
export -f cleanup_brew_locks
export -f would_brew_be_blocked
