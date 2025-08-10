#!/usr/bin/env bash
set -euo pipefail

echo "🐍 Installing Python 3.11+ on Ubuntu..."

# Ubuntu 22.04 ships with 3.10, need deadsnakes PPA for newer versions
echo "📦 Adding deadsnakes PPA for modern Python..."
sudo apt update
sudo apt install -y software-properties-common
sudo add-apt-repository -y ppa:deadsnakes/ppa
sudo apt update

# Install latest stable Python with pip
echo "📦 Installing Python..."
sudo apt install -y python3 python3-venv python3-pip

# If system Python is too old, install newer version
if ! python3 -c 'import sys; exit(0 if sys.version_info >= (3, 11) else 1)' 2>/dev/null; then
    echo "📦 System Python too old, installing newer version..."
    sudo apt install -y python3.12 python3.12-venv
    sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 100
fi

# Verify installation
INSTALLED_VERSION=$(python3 --version 2>&1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+')
echo "✅ Python $INSTALLED_VERSION installed"