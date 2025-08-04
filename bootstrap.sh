#!/usr/bin/env bash
set -euo pipefail

echo "🚀 Dotfiles Bootstrap"
echo ""

# Check if configured
if [ ! -f ~/.dotfiles.env ]; then
    echo "❌ Not configured yet. Run: ./configure.sh"
    exit 1
fi

# Load configuration
source ~/.dotfiles.env

echo "📊 Using configuration:"
echo "  Platform: $DOTFILES_PLATFORM"
if [ -n "${DOTFILES_LEVEL:-}" ]; then
    echo "  ⚠️  Warning: Legacy DOTFILES_LEVEL detected in environment, ignoring"
fi
echo ""

# Validate configuration
if [ -z "$DOTFILES_PLATFORM" ]; then
    echo "❌ Invalid configuration. Run: ./configure.sh or ./configure-p1p2.sh"
    exit 1
fi

# Define platform-specific requirements
case "$DOTFILES_PLATFORM" in
    arch)
        REQUIRED_TOOLS="stow python3 just"
        PLATFORM_MSG="🏛️ Arch: stow, python3, just"
        ;;
    ubuntu)
        REQUIRED_TOOLS="stow python3 just brew"
        PLATFORM_MSG="🐧 Ubuntu: stow, python3, just, homebrew"
        ;;
    osx)
        REQUIRED_TOOLS="stow python3 just brew"
        PLATFORM_MSG="🍎 macOS: stow, python3, just, homebrew"
        ;;
    *)
        echo "❌ Unsupported platform: $DOTFILES_PLATFORM"
        exit 1
        ;;
esac

echo "🔍 Checking required tools for $DOTFILES_PLATFORM..."
echo "   Required: $PLATFORM_MSG"
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
    cd bootstrap
    
    # Always use basic bootstrap (essential tools only) for P1/P2 system
    BOOTSTRAP_LEVEL="basic"
    
    # Run platform-specific bootstrap scripts (visible in bootstrap/ folder)
    echo "🔧 Running $BOOTSTRAP_LEVEL bootstrap for $DOTFILES_PLATFORM..."
    case "$DOTFILES_PLATFORM" in
        arch)
            echo "🏛️ Arch Basic Bootstrap - Essential tools"
            ./install-python3-arch.sh
            ./install-just-arch.sh
            # stow comes from system packages on Arch
            sudo pacman -S --noconfirm stow
            ;;
        ubuntu)
            echo "🐧 Ubuntu Basic Bootstrap - Essential tools"
            ./install-python3-ubuntu.sh
            ./install-stow-ubuntu.sh
            ./install-just-ubuntu.sh
            ./install-homebrew-linux.sh
            ;;
        osx)
            echo "🍎 macOS Basic Bootstrap - Essential tools"
            ./install-python3-osx.sh
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

echo ""
echo "✅ Bootstrap completed!"
echo ""
echo "Next steps:"
echo "  just stow           # Deploy configurations"
echo "  just health-check   # Verify setup"