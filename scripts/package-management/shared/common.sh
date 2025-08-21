#!/usr/bin/env bash
# Shared utilities for package manager initialization scripts

set -euo pipefail

# Default log configuration
LOG_DIR="${LOG_DIR:-${HOME}/logs}"
LOG_FILE="${LOG_FILE:-${LOG_DIR}/dev-package-init-$(date +%Y%m%d-%H%M%S).log}"

# Create log directory if it doesn't exist
mkdir -p "${LOG_DIR}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_output() {
    local message="$1"
    echo -e "${message}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ${message}" >> "${LOG_FILE}"
}

log_verbose() {
    local message="$1"
    if [[ "${VERBOSE:-false}" == "true" ]]; then
        echo -e "${CYAN}[VERBOSE]${NC} ${message}"
    fi
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [VERBOSE] ${message}" >> "${LOG_FILE}"
}

log_error() {
    local message="$1"
    echo -e "${RED}[ERROR]${NC} ${message}" >&2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] ${message}" >> "${LOG_FILE}"
}

log_success() {
    local message="$1"
    echo -e "${GREEN}[SUCCESS]${NC} ${message}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] ${message}" >> "${LOG_FILE}"
}

log_info() {
    local message="$1"
    echo -e "${BLUE}[INFO]${NC} ${message}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] ${message}" >> "${LOG_FILE}"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Initialize arrays for tracking
initialize_tracking_arrays() {
    initialized_pms=()
    failed_pms=()
    skipped_pms=()
}

# Print summary
print_summary() {
    local script_name="$1"
    
    log_output ""
    log_output "📊 ${script_name} Summary"
    log_output "$(printf '=%.0s' {1..50})"
    
    if [[ ${#initialized_pms[@]} -gt 0 ]]; then
        log_success "Successfully initialized: ${initialized_pms[*]}"
    fi
    
    if [[ ${#failed_pms[@]} -gt 0 ]]; then
        log_error "Failed to initialize: ${failed_pms[*]}"
    fi
    
    if [[ ${#skipped_pms[@]} -gt 0 ]]; then
        log_info "Skipped (not available): ${skipped_pms[*]}"
    fi
    
    log_output ""
    log_output "Full log available at: ${LOG_FILE}"
}