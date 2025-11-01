#!/usr/bin/env bash
# Stow wrapper with logging

set -euo pipefail

# Set up logging
LOG_DIR="${HOME}/.dotfiles/logs"
LOG_FILE="${LOG_DIR}/stow-$(date +%Y%m%d-%H%M%S).log"

# Create log directory if it doesn't exist
mkdir -p "${LOG_DIR}"

# Initialize log file with header
{
    echo "Stow Operation Log"
    echo "=================="
    echo "Date: $(date)"
    echo "Machine: $(hostname 2>/dev/null || echo 'unknown')"
    echo "User: ${USER:-$(whoami)}"
    echo "Script: $0 $*"
    echo "=================="
    echo ""
} > "${LOG_FILE}"

# Track results for summary
successes=()
failures=()

# Function to log both to console and file
log_output() {
    echo "$1" | tee -a "${LOG_FILE}"
}

# Function to log only to file (for verbose details)
log_verbose() {
    echo "$1" >> "${LOG_FILE}"
}

# Get platform from argument or environment
PLATFORM="$1"

log_output "🔗 Stowing ${PLATFORM} configurations using environment-driven approach..."

# Check if configured
if [ ! -f "$HOME/.dotfiles.env" ]; then
    log_output "❌ Configuration file missing. Run configuration first"
    exit 1
fi

# Load configuration
source "$HOME/.dotfiles.env"
log_verbose "Loaded configuration from ~/.dotfiles.env"
log_verbose "DOTFILES_PLATFORM: ${DOTFILES_PLATFORM:-'not set'}"
log_verbose "DOTFILES_MACHINE_CLASS: ${DOTFILES_MACHINE_CLASS:-'not set'}"

# Use stow.txt file from machine class directory (single source of truth)
STOW_FILE="machine-classes/${DOTFILES_MACHINE_CLASS}/stow/stow.txt"
log_output "📂 Stowing configurations using machine class stow.txt..."
log_verbose "Using stow file: ${STOW_FILE}"

if [ ! -f "${STOW_FILE}" ]; then
    log_output "❌ Stow configuration file not found: ${STOW_FILE}"
    exit 1
fi

# Read stow.txt and process each line
cd configs
while IFS= read -r stow_entry; do
    # Skip empty lines and comments
    [[ -z "$stow_entry" || "$stow_entry" =~ ^[[:space:]]*# ]] && continue

    # With flat structure, stow_entry is the package name directly
    stow_package="$stow_entry"

    log_verbose "Stowing: $stow_package"

    # Backup conflicting shell files before stowing shell_common
    if [ "$stow_package" = "shell_common" ]; then
        for f in .bashrc .bash_profile .profile .zshenv .zprofile .zlogin .zshrc; do
            if [ -f "$HOME/$f" ] && [ ! -L "$HOME/$f" ]; then
                mv "$HOME/$f" "$HOME/$f.backup-$(date +%Y%m%d)"
            fi
        done
    fi

    if [ -d "$stow_package" ]; then
        # Check if package has .stowrc with --no-folding (for file-level symlinking)
        stow_opts="--restow --dotfiles --target=$HOME"
        if [ -f "$stow_package/.stowrc" ] && grep -q "no-folding" "$stow_package/.stowrc"; then
            stow_opts="$stow_opts --no-folding"
            log_verbose "Using --no-folding for: $stow_package (file-level symlinking)"
        fi

        # Allow explicit override via environment: STOW_CMD="/path/to/stow"
        if [ -n "${STOW_CMD:-}" ]; then
            STOW_ARGS=($stow_opts "$stow_package")
        # On Windows, prefer MSYS2's perl via msys2_shell.cmd to avoid Git's perl
        elif [[ "$(uname -s)" == MINGW* || "$(uname -s)" == MSYS* ]]; then
            # Detect MSYS2 root from .dotfiles.env or common locations
            msys2_root=""
            if [ -n "${MSYS2_ROOT:-}" ]; then
                msys2_root="$MSYS2_ROOT"
            elif [ -f "/c/msys64/usr/bin/stow" ]; then
                msys2_root="/c/msys64"
            elif [ -f "/c/tools/msys64/usr/bin/stow" ]; then
                msys2_root="/c/tools/msys64"
            fi

            if [ -n "$msys2_root" ]; then
                # Build stow command to run via msys2_shell.cmd (ensures MSYS2 perl is used)
                # Note: avoid adding extra quotes around package name to prevent stow seeing literal quotes
                stow_cmd_str="cd $(pwd) && stow $stow_opts $stow_package"
                STOW_CMD="$msys2_root/msys2_shell.cmd"
                STOW_ARGS=('-defterm' '-no-start' '-c' "$stow_cmd_str")
            else
                # Fallback: if plain stow exists on PATH, use it instead of hard failing
                if command -v stow >/dev/null 2>&1; then
                    log_output "⚠️  MSYS2 not found; using stow from PATH"
                    STOW_CMD="stow"
                    STOW_ARGS=($stow_opts "$stow_package")
                else
                    log_output "❌ Cannot find MSYS2 stow and no 'stow' on PATH. Install MSYS2+stow or set STOW_CMD"
                    exit 1
                fi
            fi
        else
            # Non-Windows: use stow from PATH
            STOW_CMD="stow"
            STOW_ARGS=($stow_opts "$stow_package")
        fi

        log_verbose "STOW_CMD: ${STOW_CMD}"
        log_verbose "STOW_ARGS: ${STOW_ARGS[*]}"
        if "${STOW_CMD}" "${STOW_ARGS[@]}" 2>>"${LOG_FILE}"; then
            log_verbose "Successfully stowed: $stow_package"
            successes+=("$stow_package")
        else
            log_verbose "Failed to stow: $stow_package (exit code: $?)"
            log_output "⚠️  Some configs may not apply"
            failures+=("$stow_package")
        fi
    else
        log_verbose "Directory not found, skipping: $stow_package"
    fi
done < "../${STOW_FILE}"

cd ..
log_verbose "Returned to root directory"

# Summary UI
log_output ""
log_output "📊 Stow summary"
log_output "   • Succeeded: ${#successes[@]}"
log_output "   • Failed:    ${#failures[@]}"
if [ ${#failures[@]} -gt 0 ]; then
    log_output "   • Failed packages: ${failures[*]}"
    log_output ""
    log_output "💡 For diagnostics and fixes:"
    log_output "   just doctor-check-health"
fi

log_output ""
log_output "✅ Stow operation completed (GNU Stow only reports errors)"
log_output ""
log_output "💡 To verify symlinks were created successfully, run:"
log_output "   Run system health check to verify symlinks"
log_output ""
log_output "📝 Note: The health check will show:"
log_output "   - Number of symlinks created"
log_output "   - Any broken or missing links"
log_output "   - Overall system health status"

log_output ""
log_output "📝 Stow session logged to: ${LOG_FILE}"

# Log final status to file
{
    echo ""
    echo "=== STOW COMPLETION ==="
    echo "Platform: $PLATFORM"
    echo "DOTFILES_PLATFORM: ${DOTFILES_PLATFORM:-'not set'}"
    echo "DOTFILES_MACHINE_CLASS: ${DOTFILES_MACHINE_CLASS:-'not set'}"
    echo "Status: SUCCESS"
    echo "======================="
    echo ""
    echo "Stow completed at: $(date)"
} >> "${LOG_FILE}"
