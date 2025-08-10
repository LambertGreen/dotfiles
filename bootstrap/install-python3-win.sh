#!/usr/bin/env bash
set -euo pipefail

echo "🐍 Installing Python on Windows (MSYS2)..."

# Install Python via pacman in MSYS2
echo "📦 Installing Python via MSYS2 pacman..."
pacman -S --needed --noconfirm mingw-w64-x86_64-python mingw-w64-x86_64-python-pip

# Verify installation
INSTALLED_VERSION=$(python3 --version 2>&1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+')
echo "✅ Python $INSTALLED_VERSION installed"