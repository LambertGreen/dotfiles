#!/usr/bin/env bash
set -euo pipefail

echo "⚡ Installing Just on macOS..."

# Check if just is already installed
if command -v just >/dev/null 2>&1; then
    CURRENT_VERSION=$(just --version | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1)
    echo "✅ just ${CURRENT_VERSION} is already installed"
    exit 0
fi

# Install via Homebrew
if command -v brew >/dev/null 2>&1; then
    echo "📦 Installing just via Homebrew..."
    brew install just
else
    echo "❌ Homebrew not found - required for just installation"
    echo "💡 Please install Homebrew first: ./install-homebrew-osx.sh"
    exit 1
fi

echo "✅ Just installed successfully"
just --version