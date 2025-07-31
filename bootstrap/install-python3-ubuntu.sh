#!/usr/bin/env bash
set -euo pipefail

echo "🐍 Installing Python3 on Ubuntu..."
sudo apt update
sudo apt install -y python3 python3-pip
echo "✅ Python3 installed via apt"
echo "📦 Installing tomli for TOML parsing (Python 3.10 compatibility)..."
python3 -m pip install --user tomli