#!/usr/bin/env bash
set -euo pipefail

echo "🐍 Installing Python 3 on Ubuntu..."

# Check if Python 3 is already installed
if command -v python3 >/dev/null 2>&1; then
    echo "✅ Python 3 is already installed: $(python3 --version)"
    exit 0
fi

# Update package index
echo "📦 Updating package index..."
sudo apt-get update

# Install Python 3 and pip
echo "📦 Installing Python 3 and pip..."
sudo apt-get install -y python3 python3-pip

# Verify installation
if command -v python3 >/dev/null 2>&1; then
    echo "✅ Python 3 installed successfully: $(python3 --version)"
else
    echo "❌ Failed to install Python 3"
    exit 1
fi
