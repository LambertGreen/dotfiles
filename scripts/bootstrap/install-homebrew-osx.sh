#!/usr/bin/env bash
set -euo pipefail

echo "🍺 Installing Homebrew on macOS..."

# Check if Homebrew is already installed
if command -v brew >/dev/null 2>&1; then
    echo "✅ Homebrew is already installed"
    brew --version
    exit 0
fi

echo "📥 Downloading and installing Homebrew..."
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Add Homebrew to PATH for the rest of this session
if [[ -x "/opt/homebrew/bin/brew" ]]; then
    # Apple Silicon Mac
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x "/usr/local/bin/brew" ]]; then
    # Intel Mac
    eval "$(/usr/local/bin/brew shellenv)"
fi

echo "✅ Homebrew installed successfully"
brew --version