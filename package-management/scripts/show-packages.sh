#!/usr/bin/env bash
# Show packages configured for current machine class

set -euo pipefail

MACHINE_CLASS_ENV="${HOME}/.dotfiles.env"
PACKAGE_MANAGEMENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOTFILES_ROOT="$(cd "${PACKAGE_MANAGEMENT_DIR}/.." && pwd)"
MACHINES_DIR="${PACKAGE_MANAGEMENT_DIR}/machines"

# Set up logging
LOG_DIR="${DOTFILES_ROOT}/logs"
LOG_FILE="${LOG_DIR}/show-packages-$(date +%Y%m%d-%H%M%S).log"

# Create log directory if it doesn't exist
mkdir -p "${LOG_DIR}"

# Initialize log file with header
{
    echo "Show Packages Log"
    echo "================="
    echo "Date: $(date)"
    echo "Machine: $(hostname 2>/dev/null || echo 'unknown')"
    echo "User: ${USER:-$(whoami)}"
    echo "Script: $0 $*"
    echo "================="
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

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            echo "Usage: $0"
            echo ""
            echo "Shows all packages configured for the current machine class"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0"
            exit 1
            ;;
    esac
done

# Load machine class from environment
if [[ ! -f "${MACHINE_CLASS_ENV}" ]]; then
    echo -e "${RED}Error:${NC} Configuration file not found: ${MACHINE_CLASS_ENV}"
    echo "Run 'just configure' first"
    exit 1
fi

source "${MACHINE_CLASS_ENV}"

if [[ -z "${DOTFILES_MACHINE_CLASS:-}" ]]; then
    echo -e "${RED}Error:${NC} DOTFILES_MACHINE_CLASS not set"
    echo "Run './package-management/scripts/configure-machine-class.sh' to configure"
    exit 1
fi

MACHINE_DIR="${MACHINES_DIR}/${DOTFILES_MACHINE_CLASS}"

if [[ ! -d "${MACHINE_DIR}" ]]; then
    echo -e "${RED}Error:${NC} Machine class directory not found: ${MACHINE_DIR}"
    echo "Available machine classes:"
    ls "${MACHINES_DIR}" | sed 's/^/  - /'
    exit 1
fi

echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Package Configuration for: ${YELLOW}${DOTFILES_MACHINE_CLASS}${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
echo ""

# First, collect counts for summary
declare -A package_counts
total_packages=0

# Function to count packages
count_packages() {
    local pm="$1"
    local pm_dir="$2"
    local file="$3"
    local pattern="${4:-}"
    
    if [[ ! -f "${pm_dir}/${file}" ]]; then
        return 1
    fi
    
    local packages
    if [[ -n "${pattern}" ]]; then
        packages=$(grep "${pattern}" "${pm_dir}/${file}" 2>/dev/null | grep -v '^#' | grep -v '^$' || true)
    else
        packages=$(grep -v '^#' "${pm_dir}/${file}" 2>/dev/null | grep -v '^$' || true)
    fi
    
    local count=$(echo "${packages}" | grep -c . || echo 0)
    package_counts["${pm}"]=${count}
    total_packages=$((total_packages + count))
    
    return 0
}

# Function to show packages from a file
show_packages() {
    local pm="$1"
    local pm_dir="$2"
    local file="$3"
    local pattern="${4:-}"
    local max_lines="${5:-20}"
    
    if [[ ! -f "${pm_dir}/${file}" ]]; then
        return 1
    fi
    
    local packages
    if [[ -n "${pattern}" ]]; then
        packages=$(grep "${pattern}" "${pm_dir}/${file}" 2>/dev/null | grep -v '^#' | grep -v '^$' || true)
    else
        packages=$(grep -v '^#' "${pm_dir}/${file}" 2>/dev/null | grep -v '^$' || true)
    fi
    
    local count=$(echo "${packages}" | grep -c . || echo 0)
    
    if [[ ${count} -eq 0 ]]; then
        return 1
    fi
    
    echo -e "${MAGENTA}── ${pm} (${file}) ──${NC}"
    echo "${packages}" | sed 's/^/  /'
    echo ""
    
    return 0
}

# Function to count Brewfile packages
count_brewfile() {
    local pm_dir="$1"
    
    if [[ ! -f "${pm_dir}/Brewfile" ]]; then
        return 1
    fi
    
    local brew_count=$(grep '^brew ' "${pm_dir}/Brewfile" 2>/dev/null | wc -l | tr -d ' ')
    local cask_count=$(grep '^cask ' "${pm_dir}/Brewfile" 2>/dev/null | wc -l | tr -d ' ')
    local mas_count=$(grep '^mas ' "${pm_dir}/Brewfile" 2>/dev/null | wc -l | tr -d ' ')
    
    local total=$((brew_count + cask_count + mas_count))
    package_counts["brew"]="${brew_count} formulae, ${cask_count} casks, ${mas_count} Mac App Store"
    total_packages=$((total_packages + total))
    
    return 0
}

# Function to show Brewfile contents
show_brewfile() {
    local pm_dir="$1"
    
    if [[ ! -f "${pm_dir}/Brewfile" ]]; then
        return 1
    fi
    
    local brews=$(grep '^brew ' "${pm_dir}/Brewfile" 2>/dev/null | sed 's/brew "\([^"]*\)".*/\1/' || true)
    local casks=$(grep '^cask ' "${pm_dir}/Brewfile" 2>/dev/null | sed 's/cask "\([^"]*\)".*/\1/' || true)
    local mas=$(grep '^mas ' "${pm_dir}/Brewfile" 2>/dev/null | sed 's/mas "\([^"]*\)", id: \([0-9]*\)/\1 (id: \2)/' || true)
    local taps=$(grep '^tap ' "${pm_dir}/Brewfile" 2>/dev/null | sed 's/tap "\([^"]*\)".*/\1/' || true)
    
    local brew_count=0
    [[ -n "${brews}" ]] && brew_count=$(echo "${brews}" | grep -c .)
    local cask_count=0
    [[ -n "${casks}" ]] && cask_count=$(echo "${casks}" | grep -c .)
    local mas_count=0
    [[ -n "${mas}" ]] && mas_count=$(echo "${mas}" | grep -c .)
    local tap_count=0
    [[ -n "${taps}" ]] && tap_count=$(echo "${taps}" | grep -c .)
    
    echo -e "${MAGENTA}── brew (Brewfile) ──${NC}"
    
    # Show taps
    if [[ ${tap_count} -gt 0 ]]; then
        echo -e "  ${BLUE}Taps:${NC}"
        echo "${taps}" | sed 's/^/    /'
    fi
    
    # Show formulae
    if [[ ${brew_count} -gt 0 ]]; then
        echo -e "  ${BLUE}Formulae:${NC}"
        echo "${brews}" | sed 's/^/    /'
    fi
    
    # Show casks
    if [[ ${cask_count} -gt 0 ]]; then
        echo -e "  ${BLUE}Casks:${NC}"
        echo "${casks}" | sed 's/^/    /'
    fi
    
    # Show Mac App Store apps
    if [[ ${mas_count} -gt 0 ]]; then
        echo -e "  ${BLUE}Mac App Store:${NC}"
        echo "${mas}" | sed 's/^/    /'
    fi
    
    echo ""
    return 0
}

# First pass: count all packages
for pm_dir in "${MACHINE_DIR}"/*; do
    [[ ! -d "${pm_dir}" ]] && continue
    
    pm=$(basename "${pm_dir}")
    
    case "${pm}" in
        brew)
            count_brewfile "${pm_dir}"
            ;;
        apt|pacman|snap)
            count_packages "${pm}" "${pm_dir}" "packages.txt" ""
            ;;
        pip)
            count_packages "${pm}" "${pm_dir}" "requirements.txt" ""
            ;;
        npm)
            count_packages "${pm}" "${pm_dir}" "packages.txt" ""
            ;;
        gem)
            count_packages "${pm}" "${pm_dir}" "Gemfile" "^gem "
            ;;
        cargo)
            count_packages "${pm}" "${pm_dir}" "packages.txt" ""
            ;;
        scoop)
            if [[ -f "${pm_dir}/scoopfile.json" ]]; then
                local count=$(jq -r '.apps | length' "${pm_dir}/scoopfile.json" 2>/dev/null || echo 0)
                package_counts["scoop"]=${count}
                total_packages=$((total_packages + count))
            fi
            ;;
        *)
            count_packages "${pm}" "${pm_dir}" "packages.txt" ""
            ;;
    esac
done

# Show summary first
echo -e "${MAGENTA}Package Summary:${NC}"
for pm in "${!package_counts[@]}"; do
    echo -e "  ${GREEN}${pm}:${NC} ${package_counts[${pm}]}"
done | sort
echo -e "${CYAN}Total packages: ${total_packages}${NC}"
echo ""

# Track if any packages were found
found_any=false

# Second pass: show package details
for pm_dir in "${MACHINE_DIR}"/*; do
    [[ ! -d "${pm_dir}" ]] && continue
    
    pm=$(basename "${pm_dir}")
    
    case "${pm}" in
        brew)
            show_brewfile "${pm_dir}" && found_any=true
            ;;
        apt|pacman|snap)
            show_packages "${pm}" "${pm_dir}" "packages.txt" "" 20 && found_any=true
            ;;
        pip)
            show_packages "${pm}" "${pm_dir}" "requirements.txt" "" 15 && found_any=true
            ;;
        npm)
            show_packages "${pm}" "${pm_dir}" "packages.txt" "" 15 && found_any=true
            ;;
        gem)
            show_packages "${pm}" "${pm_dir}" "Gemfile" "^gem " 10 && found_any=true
            ;;
        cargo)
            show_packages "${pm}" "${pm_dir}" "packages.txt" "" 10 && found_any=true
            ;;
        scoop)
            if [[ -f "${pm_dir}/scoopfile.json" ]]; then
                if [[ "${SHOW_COUNTS}" == "true" ]]; then
                    local count=$(jq -r '.apps | length' "${pm_dir}/scoopfile.json" 2>/dev/null || echo 0)
                    echo -e "  ${GREEN}scoop${NC}: ${count} packages"
                else
                    echo -e "${MAGENTA}── scoop (scoopfile.json) ──${NC}"
                    jq -r '.apps[] | "  \(.Name // .name)"' "${pm_dir}/scoopfile.json" 2>/dev/null | head -15
                    local total=$(jq -r '.apps | length' "${pm_dir}/scoopfile.json" 2>/dev/null || echo 0)
                    [[ ${total} -gt 15 ]] && echo -e "  ${YELLOW}... and $((total - 15)) more${NC}"
                    echo ""
                fi
                found_any=true
            fi
            ;;
        *)
            # Try generic packages.txt
            show_packages "${pm}" "${pm_dir}" "packages.txt" "" 15 && found_any=true
            ;;
    esac
done

if [[ "${found_any}" != "true" ]]; then
    echo -e "${YELLOW}No package configurations found for ${DOTFILES_MACHINE_CLASS}${NC}"
    echo ""
    echo "Package managers checked:"
    ls "${MACHINE_DIR}" 2>/dev/null | sed 's/^/  - /' || echo "  (none)"
fi

echo ""
echo -e "${CYAN}───────────────────────────────────────────────────────────────────${NC}"

echo ""
echo "📝 Show packages session logged to: ${LOG_FILE}"

# Log final status to file
{
    echo ""
    echo "=== SHOW PACKAGES COMPLETION ==="
    echo "Machine class: ${DOTFILES_MACHINE_CLASS:-'not set'}"
    echo "Machine directory: ${MACHINE_DIR}"
    echo "===================================="
    echo ""
    echo "Show packages completed at: $(date)"
} >> "${LOG_FILE}"