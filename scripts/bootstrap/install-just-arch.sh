#!/usr/bin/env bash
set -euo pipefail

echo "⚡ Installing Just on Arch Linux..."
sudo pacman -S --needed --noconfirm just
echo "✅ Just installed via pacman"