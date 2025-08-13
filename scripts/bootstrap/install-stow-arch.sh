#!/usr/bin/env bash
set -euo pipefail

echo "🔗 Installing GNU Stow on Arch Linux..."

# Install via pacman
sudo pacman -S --needed --noconfirm stow

# Verify installation
INSTALLED_VERSION=$(stow --version | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1)
echo "✅ stow ${INSTALLED_VERSION} installed"