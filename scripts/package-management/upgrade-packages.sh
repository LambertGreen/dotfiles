#!/usr/bin/env bash
# Upgrade packages wrapper with interactive selection and logging

set -euo pipefail

# Set up logging
DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_DIR="${DOTFILES_ROOT}/logs"
LOG_FILE="${LOG_DIR}/upgrade-packages-$(date +%Y%m%d-%H%M%S).log"

# Create log directory if it doesn't exist
mkdir -p "${LOG_DIR}"

# Initialize log file with header
{
    echo "Upgrade Packages Log"
    echo "===================="
    echo "Date: $(date)"
    echo "Machine: $(hostname 2>/dev/null || echo 'unknown')"
    echo "User: ${USER:-$(whoami)}"
    echo "Script: $0 $*"
    echo "===================="
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

# Source interactive prompts library
PACKAGE_MANAGEMENT_DIR="${DOTFILES_ROOT}/package-management"
source "$(dirname "${BASH_SOURCE[0]}")/interactive-prompts.sh"

log_output "🔄 Package Upgrade Manager"
log_output ""

# Load configuration if available
if [[ -f ~/.dotfiles.env ]]; then
    source ~/.dotfiles.env
    log_verbose "Loaded configuration from ~/.dotfiles.env"
    log_verbose "DOTFILES_PLATFORM: ${DOTFILES_PLATFORM:-'not set'}"
    log_verbose "DOTFILES_MACHINE_CLASS: ${DOTFILES_MACHINE_CLASS:-'not set'}"
else
    log_output "❌ No ~/.dotfiles.env found. Run: just configure"
    exit 1
fi

# Find the most recent check-packages log
LATEST_CHECK_LOG=$(ls -t "${LOG_DIR}"/check-packages-*.log 2>/dev/null | head -1 || echo "")

if [[ -z "$LATEST_CHECK_LOG" ]]; then
    log_output "⚠️  No recent check-packages log found."
    log_output "📝 Run 'just check-packages' first to see what updates are available."
    exit 1
fi

log_output "📋 Using check results from: $(basename "$LATEST_CHECK_LOG")"
log_verbose "Latest check log: $LATEST_CHECK_LOG"

# Parse the check log to see what package managers have updates
AVAILABLE_UPGRADES=()
PM_DESCRIPTIONS=()

# Check for brew updates
if grep -q "Homebrew updates available" "$LATEST_CHECK_LOG" || grep -q "outdated.*brew" "$LATEST_CHECK_LOG"; then
    AVAILABLE_UPGRADES+=("brew")
    if brew_packages=$(grep -A 20 "=== Homebrew ===" "$LATEST_CHECK_LOG" | grep -v "===\|Running:\|All.*up to date" | head -10); then
        if [[ -n "$brew_packages" ]] && [[ "$brew_packages" != *"locked"* ]]; then
            PM_DESCRIPTIONS+=("brew (Homebrew) - packages available for upgrade")
        else
            PM_DESCRIPTIONS+=("brew (Homebrew) - updates available (details unavailable due to lock)")
        fi
    else
        PM_DESCRIPTIONS+=("brew (Homebrew) - updates available")
    fi
    log_verbose "Found brew updates in check log"
fi

# Check for pip updates
if grep -q "pip.*updates available" "$LATEST_CHECK_LOG"; then
    AVAILABLE_UPGRADES+=("pip")
    if pip_packages=$(grep -A 10 "Package.*Version.*Latest" "$LATEST_CHECK_LOG" | grep -v "Package\|------" | head -5); then
        pip_count=$(echo "$pip_packages" | wc -l | tr -d ' ')
        PM_DESCRIPTIONS+=("pip (Python) - $pip_count packages available for upgrade")
        log_verbose "Found pip packages: $pip_packages"
    else
        PM_DESCRIPTIONS+=("pip (Python) - updates available")
    fi
    log_verbose "Found pip updates in check log"
fi

# Check for npm updates
if grep -q "npm.*updates available" "$LATEST_CHECK_LOG"; then
    AVAILABLE_UPGRADES+=("npm")
    PM_DESCRIPTIONS+=("npm (Node.js) - global packages available for upgrade")
    log_verbose "Found npm updates in check log"
fi

# Check for zinit updates
if grep -q "zinit.*plugins.*updates available" "$LATEST_CHECK_LOG" || grep -q "Found.*zinit plugins" "$LATEST_CHECK_LOG"; then
    AVAILABLE_UPGRADES+=("zinit")
    if plugin_info=$(grep "Found.*zinit plugins" "$LATEST_CHECK_LOG" | head -1); then
        PM_DESCRIPTIONS+=("zinit (Zsh plugins) - $plugin_info")
    else
        PM_DESCRIPTIONS+=("zinit (Zsh plugins) - plugins available for upgrade")
    fi
    log_verbose "Found zinit updates in check log"
fi

# Check for apt updates
if grep -q "APT.*updates available" "$LATEST_CHECK_LOG" || grep -q "apt.*upgradable" "$LATEST_CHECK_LOG"; then
    AVAILABLE_UPGRADES+=("apt")
    PM_DESCRIPTIONS+=("apt (Ubuntu packages) - packages available for upgrade")
    log_verbose "Found apt updates in check log"
fi

# Show what we found
if [[ ${#AVAILABLE_UPGRADES[@]} -eq 0 ]]; then
    log_output "✅ No package managers have updates available based on last check."
    log_output "📝 Run 'just check-packages' to refresh and check for new updates."
    exit 0
fi

log_output "📦 Package managers with available updates:"
for i in "${!PM_DESCRIPTIONS[@]}"; do
    log_output "  $((i+1)). ${PM_DESCRIPTIONS[i]}"
done
log_output ""

# Interactive selection with opt-out
log_output "🎯 Interactive Package Manager Selection"
log_output "By default, all package managers with updates will be upgraded."
log_output ""

# Use the opt-out selection - but we need to fix the display issue
# For now, let's implement a simpler version that works
log_output "Package managers to upgrade:"
for i in "${!PM_DESCRIPTIONS[@]}"; do
    log_output "  $((i+1)). ${PM_DESCRIPTIONS[i]}"
done
log_output ""

SELECTED_PMS=()
log_output "Enter numbers to EXCLUDE (e.g., '1 3' to skip brew and apt) [timeout: 15s]:"
read -t 15 -r user_input || user_input=""

if [[ -n "$user_input" ]]; then
    log_output "Excluding selected package managers..."
    excluded_numbers=($user_input)

    for i in "${!AVAILABLE_UPGRADES[@]}"; do
        excluded=false
        for num in "${excluded_numbers[@]}"; do
            if [[ "$num" == "$((i+1))" ]]; then
                excluded=true
                log_output "  - Excluding: ${PM_DESCRIPTIONS[i]}"
                break
            fi
        done
        if [[ "$excluded" != true ]]; then
            SELECTED_PMS+=("${AVAILABLE_UPGRADES[i]}")
        fi
    done
else
    log_output "No exclusions specified, proceeding with all package managers..."
    SELECTED_PMS=("${AVAILABLE_UPGRADES[@]}")
fi

if [[ ${#SELECTED_PMS[@]} -eq 0 ]]; then
    log_output "⚠️  No package managers selected for upgrade."
    exit 0
fi

log_output ""
log_output "🚀 Upgrading selected package managers: ${SELECTED_PMS[*]}"
log_output ""

# Execute upgrades
for pm in "${SELECTED_PMS[@]}"; do
    log_output "=== Upgrading $pm ==="

    case "$pm" in
        brew)
            log_verbose "Running: brew upgrade"
            if brew upgrade 2>&1 | tee -a "${LOG_FILE}"; then
                log_output "✅ Homebrew upgrade completed"
            else
                log_output "⚠️  Homebrew upgrade had issues (exit code: $?)"
            fi
            ;;

        pip)
            log_verbose "Upgrading pip packages based on check results"
            # Extract package names from the check log and upgrade them
            if pip_packages=$(grep -A 10 "Package.*Version.*Latest" "$LATEST_CHECK_LOG" | grep -v "Package\|------\|===\|Running:\|All\|No\|updates" | awk '{print $1}' | grep -v '^$' | head -10); then
                pip_cmd="pip3"
                command -v pip3 >/dev/null 2>&1 || pip_cmd="pip"
                pip_flags="--user"
                if [[ "$OSTYPE" == "darwin"* ]] && command -v brew >/dev/null 2>&1; then
                    pip_flags="--user --break-system-packages"
                fi

                echo "$pip_packages" | while read -r package; do
                    if [[ -n "$package" ]]; then
                        log_verbose "Running: ${pip_cmd} install ${pip_flags} --upgrade $package"
                        if ${pip_cmd} install ${pip_flags} --upgrade "$package" 2>&1 | tee -a "${LOG_FILE}"; then
                            log_output "✅ Upgraded $package"
                        else
                            log_output "⚠️  Failed to upgrade $package"
                        fi
                    fi
                done
            else
                log_output "⚠️  Could not extract pip package names from check log"
            fi
            ;;

        npm)
            log_verbose "Running: npm update -g"
            if npm update -g 2>&1 | tee -a "${LOG_FILE}"; then
                log_output "✅ NPM global packages upgraded"
            else
                log_output "⚠️  NPM upgrade had issues (exit code: $?)"
            fi
            ;;

        zinit)
            log_verbose "Running: zinit update --all in zsh context"
            # Use timeout to prevent hanging and run in proper zsh context
            if timeout 120 zsh -c 'source ~/.zinit/bin/zinit.zsh 2>/dev/null && zinit update --all' 2>&1 | tee -a "${LOG_FILE}"; then
                log_output "✅ Zinit plugins updated"
                # Also run cclear to clean up and recompile
                log_verbose "Running: zinit cclear (cleanup and recompile)"
                timeout 60 zsh -c 'source ~/.zinit/bin/zinit.zsh 2>/dev/null && zinit cclear' 2>&1 | tee -a "${LOG_FILE}" || true
            else
                log_output "⚠️  Zinit update had issues (exit code: $?)"
            fi
            ;;

        apt)
            log_verbose "Running: sudo apt upgrade -y"
            log_output "Note: APT upgrade requires sudo permissions"
            if sudo apt upgrade -y 2>&1 | tee -a "${LOG_FILE}"; then
                log_output "✅ APT packages upgraded"
            else
                log_output "⚠️  APT upgrade had issues (exit code: $?)"
            fi
            ;;

        *)
            log_output "⚠️  Unknown package manager: $pm"
            ;;
    esac

    log_output ""
done

log_output "📊 Upgrade Summary"
log_output "=================="
log_output "✅ Attempted upgrades for: ${SELECTED_PMS[*]}"
log_output ""
log_output "💡 Next steps:"
log_output "  just check-packages  - Check for any remaining updates"
log_output "  just check-health    - Verify system health"

log_output ""
log_output "📝 Upgrade session logged to: ${LOG_FILE}"

# Log final status to file
{
    echo ""
    echo "=== UPGRADE PACKAGES COMPLETION ==="
    echo "Based on check log: $(basename "$LATEST_CHECK_LOG")"
    echo "Available package managers: ${AVAILABLE_UPGRADES[*]:-none}"
    echo "Selected package managers: ${SELECTED_PMS[*]:-none}"
    echo "DOTFILES_PLATFORM: ${DOTFILES_PLATFORM:-'not set'}"
    echo "DOTFILES_MACHINE_CLASS: ${DOTFILES_MACHINE_CLASS:-'not set'}"
    echo "===================================="
    echo ""
    echo "Upgrade packages completed at: $(date)"
} >> "${LOG_FILE}"
