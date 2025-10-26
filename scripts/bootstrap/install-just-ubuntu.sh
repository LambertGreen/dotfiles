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

# Install just using direct binary download (more reliable than installer script)
echo "⬇️  Downloading and installing just..."
JUST_VERSION="1.42.4"
ARCH=$(uname -m)
case $ARCH in
    x86_64) JUST_ARCH="x86_64-unknown-linux-musl" ;;
    aarch64|arm64) JUST_ARCH="aarch64-unknown-linux-musl" ;;
    *) echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
esac

cd /tmp
wget -q "https://github.com/casey/just/releases/download/${JUST_VERSION}/just-${JUST_VERSION}-${JUST_ARCH}.tar.gz"
tar -xzf "just-${JUST_VERSION}-${JUST_ARCH}.tar.gz"
sudo mv just /usr/local/bin/
rm -f "just-${JUST_VERSION}-${JUST_ARCH}.tar.gz"

# Verify installation
if command -v just >/dev/null 2>&1; then
    INSTALLED_VERSION=$(just --version | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1)
    echo "✅ just ${INSTALLED_VERSION} installed successfully"
else
    echo "❌ just installation failed"
    exit 1
fi