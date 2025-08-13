#!/bin/bash
# Bootstrap script to install yay AUR helper on Arch Linux
#
# yay provides access to Arch User Repository (AUR) packages

set -euo pipefail

echo "📦 Installing yay (AUR helper)..."

# Check if already installed
if command -v yay >/dev/null 2>&1; then
    echo "✅ yay already installed"
    yay --version
    exit 0
fi

# Install yay
echo "📥 Downloading and building yay..."
cd /tmp
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si --noconfirm
cd ..
rm -rf yay

# Verify installation
INSTALLED_VERSION=$(yay --version | head -1)
echo "✅ yay installed: ${INSTALLED_VERSION}"