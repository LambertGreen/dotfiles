#!/usr/bin/env bash
set -euo pipefail

echo "🐍 Installing Python on macOS..."

# Install via Homebrew
if command -v brew >/dev/null 2>&1; then
    echo "📦 Installing Python via Homebrew..."
    brew install python
else
    echo "❌ Homebrew not found - required for Python installation"
    echo "💡 Please install Homebrew first: ./install-homebrew-osx.sh"
    exit 1
fi

# Verify installation
INSTALLED_VERSION=$(python3 --version 2>&1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+')
echo "✅ Python $INSTALLED_VERSION installed"