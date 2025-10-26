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

# Add to shell profile for persistence across sessions
echo "🔧 Adding Homebrew to shell profiles..."
BREW_INIT='eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"'

# Add to multiple shell initialization files to ensure it's always available
echo "$BREW_INIT" >> ~/.profile
echo "$BREW_INIT" >> ~/.bashrc
# Create .zshenv if it doesn't exist (sourced for all zsh invocations)
touch ~/.zshenv
echo "$BREW_INIT" >> ~/.zshenv

# Source for current session
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# Verify installation
INSTALLED_VERSION=$(brew --version | head -1)
echo "✅ Homebrew installed: ${INSTALLED_VERSION}"

# Install essential tools via Homebrew to avoid circular dependencies
echo "📦 Installing essential Homebrew packages (curl, git)..."
# Use system tools for initial package installation
export HOMEBREW_CURL_PATH=/usr/bin/curl
export HOMEBREW_GIT_PATH=/usr/bin/git

# Install curl and git via Homebrew
if brew install curl git; then
    echo "✅ Homebrew curl and git installed successfully"
    # Now Homebrew can use its own versions
    unset HOMEBREW_CURL_PATH
    unset HOMEBREW_GIT_PATH
else
    echo "⚠️  Warning: Failed to install curl/git via Homebrew, will use system versions"
fi