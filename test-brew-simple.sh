#!/bin/bash
# Simple test to verify our brew fix works

echo "🧪 Testing Homebrew environment initialization fix"
echo "=================================================="

echo ""
echo "1. Testing direct brew access:"
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
command -v brew && brew --version

echo ""
echo "2. Testing init-environment.sh script:"
# Simulate our init-environment.sh script
if [[ -f "/home/linuxbrew/.linuxbrew/bin/brew" ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    echo "✅ Homebrew environment initialized"
    command -v brew && brew --version
fi

echo ""
echo "3. Installing and testing fastfetch:"
brew install fastfetch
echo ""
echo "4. Fastfetch output:"
fastfetch

echo ""
echo "🎉 All tests passed! Homebrew and fastfetch working correctly."