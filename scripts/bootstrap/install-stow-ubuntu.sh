#!/bin/bash
# Bootstrap script to install stow 2.4.1+ on Ubuntu
# 
# Ubuntu 24.04 LTS ships with stow 2.3.1 which has compatibility issues
# with our dotfiles structure. This script installs stow 2.4.1 from source.
# 
# Remove this workaround when Ubuntu ships with stow >= 2.4.1

set -euo pipefail

STOW_VERSION="2.4.1"
REQUIRED_PACKAGES="build-essential perl"

echo "🔧 Installing stow ${STOW_VERSION} on Ubuntu..."

# Check if we already have the right version
if command -v stow >/dev/null 2>&1; then
    CURRENT_VERSION=$(stow --version | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1)
    if [ "$(printf '%s\n' "$STOW_VERSION" "$CURRENT_VERSION" | sort -V | head -n1)" = "$STOW_VERSION" ]; then
        echo "✅ stow ${CURRENT_VERSION} is already installed (>= ${STOW_VERSION})"
        exit 0
    fi
    echo "📦 Current stow version: ${CURRENT_VERSION} (need >= ${STOW_VERSION})"
fi

# Install build dependencies
echo "📦 Installing build dependencies..."
sudo apt-get update
sudo apt-get install -y ${REQUIRED_PACKAGES}

# Download and compile stow
echo "⬇️  Downloading stow ${STOW_VERSION}..."
cd /tmp
curl -L "https://ftp.gnu.org/gnu/stow/stow-${STOW_VERSION}.tar.gz" | tar xz
cd "stow-${STOW_VERSION}"

echo "🔨 Compiling stow..."
./configure --prefix=/usr/local
make

echo "📦 Installing stow..."
sudo make install

echo "🧹 Cleaning up..."
cd /tmp
rm -rf "stow-${STOW_VERSION}"

# Verify installation
INSTALLED_VERSION=$(stow --version | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1)
echo "✅ stow ${INSTALLED_VERSION} installed successfully"