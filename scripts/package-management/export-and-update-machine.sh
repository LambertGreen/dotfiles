#!/usr/bin/env bash
# Enhanced export that can update existing machine class configuration

set -euo pipefail

# Set up logging
DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_DIR="${DOTFILES_ROOT}/.logs"
LOG_FILE="${LOG_DIR}/export-packages-$(date +%Y%m%d-%H%M%S).log"
PACKAGE_MANAGEMENT_DIR="${DOTFILES_ROOT}/package-management"

# Create log directory if it doesn't exist
mkdir -p "${LOG_DIR}"

# Initialize log file with header
{
    echo "Export Packages Log"
    echo "==================="
    echo "Date: $(date)"
    echo "Machine: $(hostname 2>/dev/null || echo 'unknown')"
    echo "User: ${USER:-$(whoami)}"
    echo "Script: $0 $*"
    echo "==================="
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
NC='\033[0m' # No Color

# Parse arguments
UPDATE_CURRENT=false
EXPORT_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --update-current)
            UPDATE_CURRENT=true
            shift
            ;;
        --export-only)
            EXPORT_ONLY=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Export current system packages and optionally update machine class"
            echo ""
            echo "OPTIONS:"
            echo "  --update-current    Update current machine class with exported packages"
            echo "  --export-only       Only export to /tmp, don't update anything"
            echo "  --help              Show this help"
            echo ""
            echo "EXAMPLES:"
            echo "  $0                     # Export to /tmp only"
            echo "  $0 --update-current    # Export and update current machine class"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Load configuration
if [[ -f ~/.dotfiles.env ]]; then
    source ~/.dotfiles.env
    log_verbose "Loaded configuration from ~/.dotfiles.env"
    log_verbose "DOTFILES_PLATFORM: ${DOTFILES_PLATFORM:-'not set'}"
    log_verbose "DOTFILES_MACHINE_CLASS: ${DOTFILES_MACHINE_CLASS:-'not set'}"
else
    log_output "❌ No ~/.dotfiles.env found. Run: just configure"
    exit 1
fi

# Set up export directory
if [[ "$UPDATE_CURRENT" == true ]] && [[ -n "${DOTFILES_MACHINE_CLASS:-}" ]]; then
    EXPORT_DIR="${PACKAGE_MANAGEMENT_DIR}/machines/${DOTFILES_MACHINE_CLASS}"
    log_output "🔄 Updating current machine class: ${DOTFILES_MACHINE_CLASS}"
    log_output "📁 Target directory: ${EXPORT_DIR}"
else
    EXPORT_DIR="/tmp/machine-export-$(date +%Y-%m-%d-%H%M%S)"
    log_output "📦 Exporting to temporary directory: ${EXPORT_DIR}"
fi

mkdir -p "${EXPORT_DIR}"
log_output ""

# Track what we export
exported_pms=()
export_errors=()

# Export Homebrew (with lock handling) - MANUAL packages only
if command -v brew >/dev/null 2>&1; then
    log_output "🍺 Exporting Homebrew packages (manually installed only)..."
    mkdir -p "${EXPORT_DIR}/brew"

    # Use brew leaves and brew list --cask to get only manually installed packages
    # brew leaves = formulae with no dependents (manually installed)
    # brew list --cask = all casks (casks don't have dependencies like formulae)
    {
        echo "# Work Mac Setup - Generated from actual system"
        echo "# Only manually installed packages (no auto-dependencies)"
        echo ""
        echo "tap \"homebrew/core\""
        echo "tap \"homebrew/cask\""
        echo ""
        echo "# CLI Tools (manually installed only)"
        brew leaves | sort | while read -r formula; do
            echo "brew \"$formula\""
        done
        echo ""
        echo "# Applications (casks)"
        brew list --cask | sort | while read -r cask; do
            echo "cask \"$cask\""
        done
        echo ""
        echo "# Mac App Store"
        if command -v mas >/dev/null 2>&1; then
            mas list | sort -k2 | while read -r id name; do
                echo "mas \"$name\", id: $id"
            done
        fi
    } > "${EXPORT_DIR}/brew/Brewfile" 2>>"${LOG_FILE}"

    if [[ -f "${EXPORT_DIR}/brew/Brewfile" ]]; then
        # Count what we exported
        formulae=$(grep -c '^brew ' "${EXPORT_DIR}/brew/Brewfile" 2>/dev/null || echo 0)
        casks=$(grep -c '^cask ' "${EXPORT_DIR}/brew/Brewfile" 2>/dev/null || echo 0)
        taps=$(grep -c '^tap ' "${EXPORT_DIR}/brew/Brewfile" 2>/dev/null || echo 0)
        mas=$(grep -c '^mas ' "${EXPORT_DIR}/brew/Brewfile" 2>/dev/null || echo 0)

        log_output "✅ Homebrew exported: ${formulae} formulae, ${casks} casks, ${taps} taps, ${mas} Mac App Store"
        exported_pms+=("brew")
        log_verbose "Homebrew export successful"
    else
        log_output "⚠️  Homebrew export failed (possibly due to lock)"
        export_errors+=("brew: locked or error")
        log_verbose "Homebrew export failed"
    fi
else
    log_verbose "Homebrew not available"
fi

# Export Python packages (user-installed only, excluding dependencies)
if command -v pip3 >/dev/null 2>&1; then
    log_output "🐍 Exporting Python packages (user-installed only)..."
    mkdir -p "${EXPORT_DIR}/pip"

    pip_cmd="pip3"
    pip_flags="--user"
    if [[ "$OSTYPE" == "darwin"* ]] && command -v brew >/dev/null 2>&1; then
        pip_flags="--user"
    fi

    # Use pip list --user to get only user-installed packages (not system/brew)
    # Then filter out common dependencies that are auto-installed
    if ${pip_cmd} list ${pip_flags} --format=freeze 2>>"${LOG_FILE}" | \
       grep -v -E "^(pip|setuptools|wheel|distlib|filelock|platformdirs)==" | \
       sort > "${EXPORT_DIR}/pip/requirements.txt"; then
        pip_count=$(grep -c . "${EXPORT_DIR}/pip/requirements.txt" 2>/dev/null || echo 0)
        log_output "✅ Python packages exported: ${pip_count} packages"
        exported_pms+=("pip")
        log_verbose "Python export successful"
    else
        log_output "⚠️  Python export failed"
        export_errors+=("pip: export error")
        log_verbose "Python export failed"
    fi
else
    log_verbose "pip3 not available"
fi

# Export NPM packages
if command -v npm >/dev/null 2>&1; then
    log_output "📦 Exporting NPM global packages..."
    mkdir -p "${EXPORT_DIR}/npm"

    if npm list -g --depth=0 --parseable 2>/dev/null | grep -v "/npm$" | sed 's/.*\///' > "${EXPORT_DIR}/npm/packages.txt"; then
        # Remove empty lines and npm itself
        sed -i.bak '/^$/d' "${EXPORT_DIR}/npm/packages.txt" 2>/dev/null || true
        rm -f "${EXPORT_DIR}/npm/packages.txt.bak" 2>/dev/null || true

        npm_count=$(grep -c . "${EXPORT_DIR}/npm/packages.txt" 2>/dev/null || echo 0)
        log_output "✅ NPM packages exported: ${npm_count} global packages"
        exported_pms+=("npm")
        log_verbose "NPM export successful"
    else
        log_output "⚠️  NPM export failed"
        export_errors+=("npm: export error")
        log_verbose "NPM export failed"
    fi
else
    log_verbose "npm not available"
fi

# Export summary
log_output ""
log_output "Exported ${#exported_pms[@]} package managers"

if [[ ${#exported_pms[@]} -gt 0 ]]; then
    log_output "✅ Successfully exported: ${exported_pms[*]}"
else
    log_output "❌ No package managers exported successfully"
fi

if [[ ${#export_errors[@]} -gt 0 ]]; then
    log_output "⚠️  Errors: ${export_errors[*]}"
fi

# Show comparison if updating current machine class
if [[ "$UPDATE_CURRENT" == true ]] && [[ -n "${DOTFILES_MACHINE_CLASS:-}" ]]; then
    log_output ""
    log_output "🔍 Before vs After Comparison:"

    # Show what we had vs what we have now
    for pm in "${exported_pms[@]}"; do
        case "$pm" in
            brew)
                if [[ -f "${EXPORT_DIR}/brew/Brewfile" ]]; then
                    new_formulae=$(grep -c '^brew ' "${EXPORT_DIR}/brew/Brewfile" 2>/dev/null || echo 0)
                    new_casks=$(grep -c '^cask ' "${EXPORT_DIR}/brew/Brewfile" 2>/dev/null || echo 0)
                    log_output "  brew: Updated to ${new_formulae} formulae, ${new_casks} casks (full system export)"
                fi
                ;;
            pip)
                if [[ -f "${EXPORT_DIR}/pip/requirements.txt" ]]; then
                    new_pip=$(grep -c . "${EXPORT_DIR}/pip/requirements.txt" 2>/dev/null || echo 0)
                    log_output "  pip: Updated to ${new_pip} packages (full system export)"
                fi
                ;;
            npm)
                if [[ -f "${EXPORT_DIR}/npm/packages.txt" ]]; then
                    new_npm=$(grep -c . "${EXPORT_DIR}/npm/packages.txt" 2>/dev/null || echo 0)
                    log_output "  npm: Updated to ${new_npm} global packages (full system export)"
                fi
                ;;
        esac
    done

    log_output ""
    log_output "🎯 Machine class ${DOTFILES_MACHINE_CLASS} updated with current system packages!"
    log_output ""
    log_output "💡 Next steps:"
    log_output "  just show-packages     # See the updated package counts"
    log_output "  git diff               # Review changes before committing"
    log_output "  git add . && git commit -m 'Update ${DOTFILES_MACHINE_CLASS} with current system packages'"
else
    log_output ""
    log_output "📁 Export saved to: ${EXPORT_DIR}"
    log_output ""
    log_output "💡 To update your current machine class (${DOTFILES_MACHINE_CLASS:-'not set'}):"
    log_output "  $0 --update-current"
fi

log_output ""
log_output "📝 Export session logged to: ${LOG_FILE}"
