#!/usr/bin/env bash
# Log analysis utilities for enhanced dotfiles logging
# Usage: source this file or call functions directly

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Default log directory - detect dotfiles root dynamically or use override
if [[ -n "${DEFAULT_LOG_DIR:-}" ]]; then
    # Use provided override
    true
elif [[ -n "${DOTFILES_DIR:-}" ]]; then
    DEFAULT_LOG_DIR="${HOME}/.dotfiles/logs"
elif [[ -d "${PWD}/.logs" ]]; then
    DEFAULT_LOG_DIR="${PWD}/.logs"
elif [[ -d "${HOME}/dotfiles/.logs" ]]; then
    DEFAULT_LOG_DIR="${HOME}/dotfiles/.logs"
else
    DEFAULT_LOG_DIR="${HOME}/.logs"
fi

# Get the most recent log file matching a pattern
get_latest_log() {
    local pattern="${1:-*}"
    local log_dir="${2:-${DEFAULT_LOG_DIR}}"

    if [[ -d "$log_dir" ]]; then
        find "$log_dir" -name "*${pattern}*" -type f | sort -r | head -1
    fi
}

# Filter logs by dotfiles prefix (our messages only)
filter_dotfiles_logs() {
    local log_file="${1:-$(get_latest_log)}"

    if [[ -n "$log_file" && -f "$log_file" ]]; then
        echo -e "${CYAN}=== DOTFILES LOG ENTRIES ===${NC}"
        echo "File: $log_file"
        echo ""
        grep '\[.*\].*\[.*\].*\[' "$log_file" | grep -E '\[(DOTFILES|SYS-UPGRADE|APP-CHECK|APP-UPGRADE|DEV-INIT)\]'
    else
        echo "No log file found"
        return 1
    fi
}

# Filter by severity level
filter_by_level() {
    local level="$1"
    local log_file="${2:-$(get_latest_log)}"

    local color_map="ERROR:$RED|WARN:$YELLOW|SUCCESS:$GREEN|INFO:$BLUE|DEBUG:$CYAN|VERBOSE:$MAGENTA"
    local level_color=$(echo "$color_map" | grep -o "${level}:[^|]*" | cut -d: -f2 || echo "$NC")

    if [[ -n "$log_file" && -f "$log_file" ]]; then
        echo -e "${level_color}=== ${level} ENTRIES ===${NC}"
        echo "File: $log_file"
        echo ""
        grep '\[.*\].*\[.*\].*\[' "$log_file" | grep "\[${level}\]" | while IFS= read -r line; do
            echo -e "${level_color}${line}${NC}"
        done
    else
        echo "No log file found"
        return 1
    fi
}

# Show log summary with counts
log_summary() {
    local log_file="${1:-$(get_latest_log)}"

    if [[ -n "$log_file" && -f "$log_file" ]]; then
        echo -e "${BLUE}=== LOG SUMMARY ===${NC}"
        echo "File: $log_file"
        echo "Size: $(du -h "$log_file" | cut -f1)"
        echo "Created: $(stat -f "%Sm" "$log_file" 2>/dev/null || stat -c "%y" "$log_file" 2>/dev/null || echo "unknown")"
        echo ""

        # Count by level
        echo -e "${YELLOW}Message Counts:${NC}"
        for level in ERROR WARN SUCCESS INFO DEBUG VERBOSE; do
            local count=$(grep '\[.*\].*\[.*\].*\[' "$log_file" 2>/dev/null | grep -c "\[${level}\]" 2>/dev/null | tr -d '\n' || echo "0")
            printf "  %-8s: %s\n" "$level" "${count:-0}"
        done

        echo ""

        # Count by source prefix
        echo -e "${CYAN}Source Counts:${NC}"
        grep '\[.*\].*\[.*\].*\[' "$log_file" 2>/dev/null | grep -o '\[[A-Z-]*\]' | head -1 | while IFS= read -r prefix; do
            local clean_prefix=$(echo "$prefix" | tr -d '[]')
            local count=$(grep '\[.*\].*\[.*\].*\[' "$log_file" | grep -c "\[${clean_prefix}\]" || echo "0")
            printf "  %-12s: %s\n" "$clean_prefix" "$count"
        done 2>/dev/null || echo "  No prefixed logs found"

        echo ""

        # Show external tool output counts
        echo -e "${MAGENTA}External Tool Output:${NC}"
        for tool in BREW ZINIT APT PACMAN; do
            local count=$(grep '\[.*\].*\[.*\].*\[' "$log_file" 2>/dev/null | grep -c "\[${tool}\]" 2>/dev/null | tr -d '\n' || echo "0")
            count="${count:-0}"
            if [[ "$count" -gt 0 ]]; then
                printf "  %-8s: %s lines\n" "$tool" "$count"
            fi
        done
    else
        echo "No log file found"
        return 1
    fi
}

# Show timing information from logs
log_timing() {
    local log_file="${1:-$(get_latest_log)}"

    if [[ -n "$log_file" && -f "$log_file" ]]; then
        echo -e "${GREEN}=== TIMING ANALYSIS ===${NC}"
        echo "File: $log_file"
        echo ""

        # Extract timestamps and calculate duration
        local first_timestamp=$(grep '\[.*\].*\[.*\].*\[' "$log_file" | head -1 | grep -o '\[[0-9-]* [0-9:]*\]' | tr -d '[]' || echo "")
        local last_timestamp=$(grep '\[.*\].*\[.*\].*\[' "$log_file" | tail -1 | grep -o '\[[0-9-]* [0-9:]*\]' | tr -d '[]' || echo "")

        if [[ -n "$first_timestamp" && -n "$last_timestamp" ]]; then
            echo "Start: $first_timestamp"
            echo "End:   $last_timestamp"

            # Show execution time if logged
            grep "Execution time:" "$log_file" 2>/dev/null | tail -1 | sed 's/.*Execution time: /Duration: /' || echo "Duration: Not calculated"
        else
            echo "No timestamp information found"
        fi

        echo ""

        # Show sections
        echo -e "${YELLOW}Sections:${NC}"
        grep '\[.*\].*\[.*\].*\[' "$log_file" | grep -E '={20,}' | sed 's/.*\] /  /' | head -10
    else
        echo "No log file found"
        return 1
    fi
}

# Quick commands for common operations
alias log-errors='filter_by_level ERROR'
alias log-warns='filter_by_level WARN'
alias log-success='filter_by_level SUCCESS'
alias log-info='filter_by_level INFO'
alias log-debug='filter_by_level DEBUG'

# Show available log files
list_logs() {
    local log_dir="${1:-${DEFAULT_LOG_DIR}}"

    if [[ -d "$log_dir" ]]; then
        echo -e "${BLUE}=== AVAILABLE LOGS ===${NC}"
        echo "Directory: $log_dir"
        echo ""
        ls -lht "$log_dir" | head -20
    else
        echo "Log directory not found: $log_dir"
        return 1
    fi
}

# Interactive log viewer
view_log() {
    local log_file="${1:-$(get_latest_log)}"

    if [[ -n "$log_file" && -f "$log_file" ]]; then
        echo "Viewing: $log_file"
        echo "Use 'q' to quit, '/' to search"
        less "$log_file"
    else
        echo "No log file found"
        return 1
    fi
}

# Export functions for use as commands
export -f get_latest_log
export -f filter_dotfiles_logs
export -f filter_by_level
export -f log_summary
export -f log_timing
export -f list_logs
export -f view_log
