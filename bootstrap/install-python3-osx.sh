#!/usr/bin/env bash
set -euo pipefail

echo "🐍 Installing Python3 on macOS..."

# Check if Python3 is already available
if command -v python3 >/dev/null 2>&1; then
    CURRENT_VERSION=$(python3 --version 2>&1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1)
    echo "✅ Python3 ${CURRENT_VERSION} is already installed"
    exit 0
fi

# Install via Homebrew if available, otherwise suggest installation
if command -v brew >/dev/null 2>&1; then
    echo "📦 Installing Python3 via Homebrew..."
    brew install python
else
    echo "❌ Python3 not found and Homebrew not available"
    echo "💡 Please install Python3 manually:"
    echo "   1. Download from https://www.python.org/downloads/"
    echo "   2. Or install Homebrew first: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    exit 1
fi

echo "✅ Python3 installed successfully"