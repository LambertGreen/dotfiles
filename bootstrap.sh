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
echo "  Level: $DOTFILES_LEVEL"
echo ""

# Validate configuration
if [ -z "$DOTFILES_PLATFORM" ] || [ -z "$DOTFILES_LEVEL" ]; then
    echo "❌ Invalid configuration. Run: ./configure.sh"
    exit 1
fi

# Check if just is available
if command -v just >/dev/null 2>&1; then
    echo "🔧 Using just command for bootstrap..."
    just bootstrap
else
    echo "🔧 Using direct bootstrap (just not yet installed)..."
    cd bootstrap
    if command -v just >/dev/null 2>&1; then
        just "bootstrap-$DOTFILES_LEVEL-$DOTFILES_PLATFORM"
    else
        echo "❌ Just command not found. Please install just first or run bootstrap manually."
        echo "Expected command: bootstrap-$DOTFILES_LEVEL-$DOTFILES_PLATFORM"
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