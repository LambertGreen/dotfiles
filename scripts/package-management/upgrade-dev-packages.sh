#!/usr/bin/env bash
# Upgrade dev packages wrapper with interactive selection and logging
# Handles application-level package managers: zsh, emacs, neovim, cargo, pipx

set -euo pipefail

# Setup
DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Configure logging
LOG_PREFIX="DEV-UPGRADE"
LOG_DIR="${DOTFILES_ROOT}/.logs"
LOG_FILE="${LOG_DIR}/upgrade-dev-packages-$(date +%Y%m%d-%H%M%S).log"

# Source enhanced logging utilities
source "${DOTFILES_ROOT}/scripts/package-management/shared/logging.sh"

# Initialize log
initialize_log "upgrade-dev-packages.sh"

# Track timing
START_TIME=$(date +%s)

# For backward compatibility with existing script
log_output() {
    log_info "$1"
}

# Function to log only to file (for verbose details)
log_verbose() {
    log_debug "$1"
}

log_output "🔄 Dev Package Upgrade Manager"
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

# Find the most recent check-dev-packages log
LATEST_CHECK_LOG=$(ls -t "${LOG_DIR}"/check-dev-packages-*.log 2>/dev/null | head -1 || echo "")

if [[ -z "$LATEST_CHECK_LOG" ]]; then
    log_output "⚠️  No recent check-dev-packages log found."
    log_output "📝 Run 'just check-dev-packages' first to see what updates are available."
    exit 1
fi

log_output "📋 Using check results from: $(basename "$LATEST_CHECK_LOG")"
log_verbose "Latest check log: $LATEST_CHECK_LOG"

# Parse the check log to see what dev package managers have updates
AVAILABLE_UPGRADES=()
PM_DESCRIPTIONS=()

# Check for zsh updates
if grep -q "Found.*zsh plugins.*updates available" "$LATEST_CHECK_LOG"; then
    AVAILABLE_UPGRADES+=("zsh")
    if plugin_info=$(grep "Found.*zsh plugins" "$LATEST_CHECK_LOG" | head -1); then
        PM_DESCRIPTIONS+=("zsh (plugins) - $plugin_info")
    else
        PM_DESCRIPTIONS+=("zsh (plugins) - updates available")
    fi
    log_verbose "Found zsh plugin updates in check log"
fi

# Check for emacs updates
if grep -q "Found.*emacs packages.*updates available" "$LATEST_CHECK_LOG"; then
    AVAILABLE_UPGRADES+=("emacs")
    if package_info=$(grep "Found.*emacs packages" "$LATEST_CHECK_LOG" | head -1); then
        PM_DESCRIPTIONS+=("emacs (packages) - $package_info")
    else
        PM_DESCRIPTIONS+=("emacs (packages) - updates available")
    fi
    log_verbose "Found emacs package updates in check log"
fi

# Check for neovim updates
if grep -q "Found.*neovim plugins.*updates available" "$LATEST_CHECK_LOG"; then
    AVAILABLE_UPGRADES+=("neovim")
    if plugin_info=$(grep "Found.*neovim plugins" "$LATEST_CHECK_LOG" | head -1); then
        PM_DESCRIPTIONS+=("neovim (plugins) - $plugin_info")
    else
        PM_DESCRIPTIONS+=("neovim (plugins) - updates available")
    fi
    log_verbose "Found neovim plugin updates in check log"
fi

# Check for cargo updates
if grep -q "Found.*cargo tools.*updates available" "$LATEST_CHECK_LOG"; then
    AVAILABLE_UPGRADES+=("cargo")
    if tool_info=$(grep "Found.*cargo tools" "$LATEST_CHECK_LOG" | head -1); then
        PM_DESCRIPTIONS+=("cargo (Rust tools) - $tool_info")
    else
        PM_DESCRIPTIONS+=("cargo (Rust tools) - updates available")
    fi
    log_verbose "Found cargo tool updates in check log"
fi

# Check for pipx updates
if grep -q "Found.*pipx tools.*updates available" "$LATEST_CHECK_LOG"; then
    AVAILABLE_UPGRADES+=("pipx")
    if tool_info=$(grep "Found.*pipx tools" "$LATEST_CHECK_LOG" | head -1); then
        PM_DESCRIPTIONS+=("pipx (Python tools) - $tool_info")
    else
        PM_DESCRIPTIONS+=("pipx (Python tools) - updates available")
    fi
    log_verbose "Found pipx tool updates in check log"
fi

# Show what we found
if [[ ${#AVAILABLE_UPGRADES[@]} -eq 0 ]]; then
    log_output "✅ No dev package managers have updates available based on last check."
    log_output "📝 Run 'just check-dev-packages' to refresh and check for new updates."
    exit 0
fi

log_output "📦 Dev package managers with available updates:"
for i in "${!PM_DESCRIPTIONS[@]}"; do
    log_output "  $((i+1)). ${PM_DESCRIPTIONS[i]}"
done
log_output ""

# Interactive selection with opt-in (default all)
log_output "🎯 Interactive Dev Package Manager Selection"
log_output "By default, all dev package managers with updates will be upgraded."
log_output ""

log_output "Package managers to upgrade:"
for i in "${!PM_DESCRIPTIONS[@]}"; do
    log_output "  $((i+1)). ${PM_DESCRIPTIONS[i]}"
done
log_output ""

SELECTED_PMS=()
log_output "Enter numbers to SELECT (e.g., '1 3' for zsh+neovim only, or ENTER for all) [timeout: 15s]:"
read -t 15 -r user_input || user_input=""

if [[ -n "$user_input" ]]; then
    log_output "Selecting specified package managers..."
    selected_numbers=($user_input)

    for num in "${selected_numbers[@]}"; do
        if [[ "$num" =~ ^[0-9]+$ ]] && [[ "$num" -ge 1 ]] && [[ "$num" -le ${#AVAILABLE_UPGRADES[@]} ]]; then
            idx=$((num-1))
            SELECTED_PMS+=("${AVAILABLE_UPGRADES[idx]}")
            log_output "  - Selected: ${PM_DESCRIPTIONS[idx]}"
        else
            log_output "  - Invalid selection: $num (skipping)"
        fi
    done
else
    log_output "No input received, proceeding with all package managers..."
    SELECTED_PMS=("${AVAILABLE_UPGRADES[@]}")
fi

if [[ ${#SELECTED_PMS[@]} -eq 0 ]]; then
    log_output "⚠️  No valid package managers selected for upgrade."
    exit 0
fi

log_output ""
log_output "🚀 Upgrading selected dev package managers: ${SELECTED_PMS[*]}"
log_output ""

# Execute upgrades
for pm in "${SELECTED_PMS[@]}"; do
    log_output "=== Upgrading $pm ==="

    case "$pm" in
        zsh)
            log_verbose "Running: zinit update --all in zsh context"
            # Use timeout to prevent hanging and run in proper zsh context
            if timeout 120 zsh -c 'source ~/.zinit/bin/zinit.zsh 2>/dev/null && zinit update --all' 2>&1 | tee -a "${LOG_FILE}"; then
                log_output "✅ Zsh plugins updated"
                # Also run cclear to clean up and recompile
                log_verbose "Running: zinit cclear (cleanup and recompile)"
                timeout 60 zsh -c 'source ~/.zinit/bin/zinit.zsh 2>/dev/null && zinit cclear' 2>&1 | tee -a "${LOG_FILE}" || true
            else
                log_output "⚠️  Zsh plugin update had issues (exit code: $?)"
            fi
            ;;

        emacs)
            log_verbose "Running: emacs with DOTFILES_EMACS_UPDATE environment variable for unattended update"
            if timeout 300 env DOTFILES_EMACS_UPDATE=1 emacs --batch -l ~/.emacs.d/init.el 2>&1 | tee -a "${LOG_FILE}"; then
                log_output "✅ Emacs packages updated"
            else
                log_output "⚠️  Emacs package update had issues (exit code: $?)"
            fi
            ;;

        neovim)
            log_verbose "Running: nvim lazy sync in headless mode"
            if timeout 300 nvim --headless "+Lazy! sync" +qa 2>&1 | tee -a "${LOG_FILE}"; then
                log_output "✅ Neovim plugins updated"
            else
                log_output "⚠️  Neovim plugin update had issues (exit code: $?)"
            fi
            ;;

        cargo)
            log_verbose "Running: cargo install-update -a"
            if command -v cargo-install-update >/dev/null 2>&1; then
                if timeout 600 cargo install-update -a 2>&1 | tee -a "${LOG_FILE}"; then
                    log_output "✅ Cargo tools updated"
                else
                    log_output "⚠️  Cargo tool update had issues (exit code: $?)"
                fi
            else
                log_output "⚠️  cargo-install-update not found. Install with: cargo install cargo-update"
            fi
            ;;

        pipx)
            log_verbose "Running: pipx upgrade-all"
            if timeout 300 pipx upgrade-all 2>&1 | tee -a "${LOG_FILE}"; then
                log_output "✅ Pipx tools updated"
            else
                log_output "⚠️  Pipx tool update had issues (exit code: $?)"
            fi
            ;;

        *)
            log_output "⚠️  Unknown dev package manager: $pm"
            ;;
    esac

    log_output ""
done

log_section "Upgrade Summary"
log_success "Attempted upgrades for: ${#SELECTED_PMS[@]} dev package managers"

log_duration "${START_TIME}"
finalize_log "SUCCESS"

log_info "Upgrade session logged to: ${LOG_FILE}"

exit 0
