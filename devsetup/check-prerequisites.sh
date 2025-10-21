#!/usr/bin/env bash
# Development Prerequisites Checker
# Checks for direnv and pyenv (the essential tools)

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "🔍 Checking development prerequisites..."
echo ""

# Check for direnv
if command -v direnv >/dev/null 2>&1; then
    echo -e "✅ ${GREEN}direnv${NC} is installed"
else
    echo -e "❌ ${RED}direnv${NC} is missing"
    echo -e "${BLUE}Install: brew install direnv${NC}"
    echo -e "${BLUE}Add to shell: eval \"\$(direnv hook zsh)\"${NC}"
    exit 1
fi

# Check for pyenv
if command -v pyenv >/dev/null 2>&1; then
    echo -e "✅ ${GREEN}pyenv${NC} is installed"
else
    echo -e "❌ ${RED}pyenv${NC} is missing"
    echo -e "${BLUE}Install: brew install pyenv${NC}"
    echo -e "${BLUE}Add to shell: eval \"\$(pyenv init -)\"${NC}"
    exit 1
fi

echo ""
echo -e "🎉 ${GREEN}All prerequisites are installed!${NC}"
echo -e "${BLUE}Run: direnv allow && eval \"\$(direnv export bash)\"${NC}"
