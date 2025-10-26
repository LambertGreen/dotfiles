#!/usr/bin/env bash
set -euo pipefail

echo "🐍 Installing Python 3 on macOS..."

# Check if Python 3 is already installed
if command -v python3 >/dev/null 2>&1; then
    echo "✅ Python 3 is already installed: $(python3 --version)"
    exit 0
fi

# Check if Homebrew is installed
if ! command -v brew >/dev/null 2>&1; then
    echo "❌ Homebrew is not installed. Install it first."
    exit 1
fi

# Install Python 3 via Homebrew
echo "📦 Installing Python 3 via Homebrew..."
brew install python3

# Verify installation
if command -v python3 >/dev/null 2>&1; then
    echo "✅ Python 3 installed successfully: $(python3 --version)"
else
    echo "❌ Failed to install Python 3"
    exit 1
fi
