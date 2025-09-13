#!/usr/bin/env bash
# Enhanced logging utilities with prefixes, timestamps, and severity levels
# Source this file in your scripts: source "${DOTFILES_ROOT}/scripts/package-management/shared/logging.sh"

set -euo pipefail

# Default log configuration
LOG_DIR="${LOG_DIR:-${HOME}/logs}"
LOG_PREFIX="${LOG_PREFIX:-DOTFILES}"  # Can be overridden per script
LOG_TIMESTAMP_FORMAT="${LOG_TIMESTAMP_FORMAT:-%Y-%m-%d %H:%M:%S}"

# Create log directory if it doesn't exist
mkdir -p "${LOG_DIR}"

# Colors for terminal output (can be disabled with NO_COLOR=1)
if [[ "${NO_COLOR:-}" == "1" ]] || [[ ! -t 1 ]]; then
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    CYAN=""
    MAGENTA=""
    BOLD=""
    NC=""
else
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    MAGENTA='\033[0;35m'
    BOLD='\033[1m'
    NC='\033[0m' # No Color
fi

# Get current timestamp
get_timestamp() {
    date "+${LOG_TIMESTAMP_FORMAT}"
}

# Core logging function with prefix and timestamp
log_with_level() {
    local level="$1"
    local color="$2"
    local message="$3"
    local timestamp="$(get_timestamp)"

    # Single output for both console and file
    local output_line="[${timestamp}] [${LOG_PREFIX}] [${level}] ${message}"

    # Terminal: show with color
    if [[ -t 1 ]] || [[ "${FORCE_TERMINAL_OUTPUT:-}" == "1" ]]; then
        echo -e "${color}${output_line}${NC}"
    else
        echo "${output_line}"
    fi

    # Also save to file
    echo "${output_line}" >> "${LOG_FILE}"
}

# Primary logging functions
log_error() {
    log_with_level "ERROR" "${RED}" "$1" >&2
}

log_warn() {
    log_with_level "WARN" "${YELLOW}" "$1"
}

log_success() {
    log_with_level "SUCCESS" "${GREEN}" "$1"
}

log_info() {
    log_with_level "INFO" "${BLUE}" "$1"
}

log_debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        log_with_level "DEBUG" "${CYAN}" "$1"
    else
        # Still log to file even if not showing in terminal
        echo "[$(get_timestamp)] [${LOG_PREFIX}] [DEBUG] $1" >> "${LOG_FILE}"
    fi
}

# Verbose logging (shown only with VERBOSE=true)
log_verbose() {
    if [[ "${VERBOSE:-false}" == "true" ]]; then
        log_with_level "VERBOSE" "${MAGENTA}" "$1"
    else
        # Still log to file
        echo "[$(get_timestamp)] [${LOG_PREFIX}] [VERBOSE] $1" >> "${LOG_FILE}"
    fi
}

# Standard output logging - same everywhere
log_output() {
    local message="$1"
    local output_line="[$(get_timestamp)] [${LOG_PREFIX}] [OUTPUT] ${message}"
    echo "${output_line}"
    echo "${output_line}" >> "${LOG_FILE}"
}


# Section separators - same output everywhere
log_section() {
    local title="$1"
    log_info "=== ${title} ==="
}

log_subsection() {
    local title="$1"
    log_info "--- ${title} ---"
}

# Log execution time
log_duration() {
    local start_time="$1"
    local end_time="${2:-$(date +%s)}"
    local duration=$((end_time - start_time))

    local hours=$((duration / 3600))
    local minutes=$(((duration % 3600) / 60))
    local seconds=$((duration % 60))

    local duration_str=""
    if [[ ${hours} -gt 0 ]]; then
        duration_str="${hours}h ${minutes}m ${seconds}s"
    elif [[ ${minutes} -gt 0 ]]; then
        duration_str="${minutes}m ${seconds}s"
    else
        duration_str="${seconds}s"
    fi

    log_info "Execution time: ${duration_str}"
}

# Check if command exists (utility function)
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Initialize log file with header
initialize_log() {
    local script_name="${1:-$(basename "$0")}"

    {
        echo "================================================================================"
        echo "[${LOG_PREFIX}] Log Session Started"
        echo "================================================================================"
        echo "Date: $(date)"
        echo "Script: ${script_name}"
        echo "Machine: $(hostname 2>/dev/null || echo 'unknown')"
        echo "User: ${USER:-$(whoami)}"
        echo "Working Directory: $(pwd)"
        echo "================================================================================"
        echo ""
    } >> "${LOG_FILE}"
}

# Finalize log with summary
finalize_log() {
    local status="${1:-SUCCESS}"

    {
        echo ""
        echo "================================================================================"
        echo "[${LOG_PREFIX}] Log Session Ended"
        echo "================================================================================"
        echo "Status: ${status}"
        echo "End Time: $(date)"
        echo "Log File: ${LOG_FILE}"
        echo "================================================================================"
    } >> "${LOG_FILE}"
}

# Export functions for use in subshells
export -f get_timestamp
export -f log_with_level
export -f log_error
export -f log_warn
export -f log_success
export -f log_info
export -f log_debug
export -f log_verbose
export -f log_output
export -f log_section
export -f log_subsection
export -f log_duration
export -f command_exists
