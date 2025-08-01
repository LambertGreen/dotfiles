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

# Check if essential tools are available
if command -v stow >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
    echo "🔧 Essential tools (stow, python3) already installed, skipping bootstrap..."
else
    echo "🔧 Installing essential tools (stow, python3 for TOML parsing)..."
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