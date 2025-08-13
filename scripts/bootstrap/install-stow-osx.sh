#!/usr/bin/env bash
set -euo pipefail

echo "🔗 Installing GNU Stow on macOS..."

# Check if stow is already installed
if command -v stow >/dev/null 2>&1; then
    CURRENT_VERSION=$(stow --version | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1)
    echo "✅ stow ${CURRENT_VERSION} is already installed"
    exit 0
fi

# Install via Homebrew
if command -v brew >/dev/null 2>&1; then
    echo "📦 Installing stow via Homebrew..."
    brew install stow
else
    echo "❌ Homebrew not found - required for stow installation"
    echo "💡 Please install Homebrew first: ./install-homebrew-osx.sh"
    exit 1
fi

echo "✅ GNU Stow installed successfully"
stow --version