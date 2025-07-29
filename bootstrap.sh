#!/usr/bin/env bash
set -euo pipefail

echo "🚀 Dotfiles Bootstrap"
echo ""

# Check if configured
if [ ! -f .dotfiles.env ]; then
    echo "❌ Not configured yet. Run: ./configure.sh"
    exit 1
fi

# Load configuration
source .dotfiles.env

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
if command -v stow >/dev/null 2>&1; then
    echo "🔧 Stow is already installed, skipping bootstrap..."
else
    echo "🔧 Installing essential tools..."
    cd bootstrap
    
    # Always use basic bootstrap (essential tools only) for P1/P2 system
    BOOTSTRAP_LEVEL="basic"
    
    if command -v just >/dev/null 2>&1; then
        just "bootstrap-$BOOTSTRAP_LEVEL-$DOTFILES_PLATFORM"
    else
        echo "❌ Just command not found. Please install just first or run bootstrap manually."
        echo "Expected command: bootstrap-$BOOTSTRAP_LEVEL-$DOTFILES_PLATFORM"
        exit 1
    fi
    cd ..
fi

echo ""
echo "✅ Bootstrap completed!"
echo ""
echo "Next steps:"
echo "  just stow           # Deploy configurations"
echo "  just health-check   # Verify setup"