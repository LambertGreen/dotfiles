#!/usr/bin/env bash
set -euo pipefail

echo "🐍 Installing Python on Arch Linux..."

# Arch typically has latest Python
sudo pacman -S --needed --noconfirm python python-pip

# Verify installation
INSTALLED_VERSION=$(python3 --version 2>&1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+')
echo "✅ Python $INSTALLED_VERSION installed"