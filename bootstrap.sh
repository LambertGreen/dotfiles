#!/usr/bin/env bash
set -euo pipefail

# Windows detection and PowerShell fallback
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ "${OS:-}" == "Windows_NT" ]]; then
    # We're on Windows - check if we have the PowerShell bootstrap script
    if [[ -f "bootstrap.ps1" ]]; then
        echo "🔄 Detected Windows environment, delegating to bootstrap.ps1..."
        powershell.exe -ExecutionPolicy Bypass -File bootstrap.ps1
        exit $?
    else
        echo "⚠️  Windows detected but bootstrap.ps1 not found, continuing with bash bootstrap..."
    fi
fi

# Set up logging
DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${DOTFILES_ROOT}/logs"
LOG_FILE="${LOG_DIR}/bootstrap-$(date +%Y%m%d-%H%M%S).log"

# Create log directory if it doesn't exist
mkdir -p "${LOG_DIR}"

# Initialize log file with header
{
    echo "Dotfiles Bootstrap Log"
    echo "======================"
    echo "Date: $(date)"
    echo "Machine: $(hostname 2>/dev/null || echo 'unknown')"
    echo "User: ${USER:-$(whoami)}"
    echo "Script: $0 $*"
    echo "======================"
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

log_output "🚀 Dotfiles Bootstrap"
log_output ""

# Check if configured
if [ ! -f ~/.dotfiles.env ]; then
    log_output "❌ Not configured yet. Run: ./configure.sh"
    exit 1
fi

# Load configuration
source ~/.dotfiles.env
log_verbose "Loaded configuration from ~/.dotfiles.env"

log_output "📊 Using configuration:"
log_output "  Platform: $DOTFILES_PLATFORM"
if [ -n "${DOTFILES_LEVEL:-}" ]; then
    log_output "  ⚠️  Warning: Legacy DOTFILES_LEVEL detected in environment, ignoring"
fi
log_output ""

# Validate configuration
if [ -z "$DOTFILES_PLATFORM" ]; then
    log_output "❌ Invalid configuration. Run: ./configure.sh or ./configure-p1p2.sh"
    exit 1
fi

# Define platform-specific requirements
case "$DOTFILES_PLATFORM" in
    arch)
        REQUIRED_TOOLS="stow just"
        PLATFORM_MSG="🏛️ Arch: stow, just"
        ;;
    ubuntu)
        REQUIRED_TOOLS="stow just brew"
        PLATFORM_MSG="🐧 Ubuntu: stow, just, homebrew"
        ;;
    osx)
        REQUIRED_TOOLS="stow just brew"
        PLATFORM_MSG="🍎 macOS: stow, just, homebrew"
        ;;
    *)
        echo "❌ Unsupported platform: $DOTFILES_PLATFORM"
        exit 1
        ;;
esac

log_output "🔍 Checking required tools for $DOTFILES_PLATFORM..."
log_output "   Required: $PLATFORM_MSG"
echo ""

# Check each required tool
ALL_TOOLS_PRESENT=true
for tool in $REQUIRED_TOOLS; do
    if command -v "$tool" >/dev/null 2>&1; then
        echo "  ✅ $tool: $(command -v "$tool")"
    else
        echo "  ❌ $tool: NOT FOUND"
        ALL_TOOLS_PRESENT=false
    fi
done
echo ""

# Decide whether to run bootstrap
if [ "$ALL_TOOLS_PRESENT" = true ]; then
    echo "✅ All required tools are already installed!"
else
    echo "🔧 Installing missing tools..."
    cd scripts/bootstrap
    
    # Always use basic bootstrap (essential tools only) for P1/P2 system
    BOOTSTRAP_LEVEL="basic"
    
    # Run platform-specific bootstrap scripts (visible in bootstrap/ folder)
    echo "🔧 Running $BOOTSTRAP_LEVEL bootstrap for $DOTFILES_PLATFORM..."
    case "$DOTFILES_PLATFORM" in
        arch)
            echo "🏛️ Arch Basic Bootstrap - Essential tools"
            ./install-just-arch.sh
            # stow comes from system packages on Arch
            sudo pacman -S --noconfirm stow
            ;;
        ubuntu)
            echo "🐧 Ubuntu Basic Bootstrap - Essential tools"
            ./install-stow-ubuntu.sh
            ./install-just-ubuntu.sh
            ./install-homebrew-linux.sh
            ;;
        osx)
            echo "🍎 macOS Basic Bootstrap - Essential tools"
            ./install-homebrew-osx.sh
            ./install-stow-osx.sh
            ./install-just-osx.sh
            ;;
        *)
            echo "❌ Unsupported platform: $DOTFILES_PLATFORM"
            exit 1
            ;;
    esac
    cd ..
fi

log_output ""
log_output "✅ Bootstrap completed!"
log_output ""
log_output "Next steps:"
log_output "  just stow           # Deploy configurations"
log_output "  just check-health   # Verify setup"

log_output ""
log_output "📝 Bootstrap session logged to: ${LOG_FILE}"

# Log final status to file
{
    echo ""
    echo "=== BOOTSTRAP COMPLETION ==="
    echo "Platform: $DOTFILES_PLATFORM"
    echo "Required tools: $PLATFORM_MSG"
    echo "Status: SUCCESS"
    echo "============================"
    echo ""
    echo "Bootstrap completed at: $(date)"
} >> "${LOG_FILE}"