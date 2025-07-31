#!/usr/bin/env bash
set -euo pipefail

echo "🐍 Installing Python3 on Arch Linux..."
sudo pacman -S --needed --noconfirm python python-pip
echo "✅ Python3 installed via pacman"