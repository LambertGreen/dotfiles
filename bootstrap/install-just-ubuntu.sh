#!/bin/bash
# Bootstrap script to install just command runner on Ubuntu
# 
# Ubuntu doesn't ship with just by default, so we install it from the
# official GitHub releases using the just.systems installer.

set -euo pipefail

echo "🔧 Installing just command runner on Ubuntu..."

# Check if just is already installed
if command -v just >/dev/null 2>&1; then
    CURRENT_VERSION=$(just --version | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1)
    echo "✅ just ${CURRENT_VERSION} is already installed"
    exit 0
fi

# Install just using the official installer
echo "⬇️  Downloading and installing just..."
curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to /usr/local/bin

# Verify installation
if command -v just >/dev/null 2>&1; then
    INSTALLED_VERSION=$(just --version | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1)
    echo "✅ just ${INSTALLED_VERSION} installed successfully"
else
    echo "❌ just installation failed"
    exit 1
fi