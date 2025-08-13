#!/bin/bash
# Bootstrap script to install Nix package manager
#
# Nix provides reproducible package management and cutting-edge packages

set -euo pipefail

echo "❄️ Installing Nix package manager..."

# Check if already installed
if command -v nix >/dev/null 2>&1; then
    echo "✅ Nix already installed"
    nix --version
    exit 0
fi

# Install Nix with daemon mode
echo "📥 Downloading and installing Nix..."
sh <(curl -L https://nixos.org/nix/install) --daemon

echo "✅ Nix installation complete"
echo "💡 Restart your shell and run: nix-env -iA nixpkgs.home-manager"