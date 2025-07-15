#!/bin/bash
# Bootstrap script to install Homebrew on Linux
#
# Homebrew provides modern package versions and cross-platform consistency

set -euo pipefail

echo "🍺 Installing Homebrew for Linux..."

# Check if already installed
if command -v brew >/dev/null 2>&1; then
    echo "✅ Homebrew already installed"
    brew --version
    exit 0
fi

# Install Homebrew
echo "📥 Downloading and installing Homebrew..."
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Add to shell profile
echo "🔧 Adding Homebrew to shell profile..."
echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.profile

# Source for current session
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# Verify installation
INSTALLED_VERSION=$(brew --version | head -1)
echo "✅ Homebrew installed: ${INSTALLED_VERSION}"