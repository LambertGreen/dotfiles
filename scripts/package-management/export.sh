#!/usr/bin/env bash
# Export current system's package configurations

set -euo pipefail

EXPORT_DIR="/tmp/machine-export-$(date +%Y-%m-%d-%H%M%S)"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Create export directory
mkdir -p "${EXPORT_DIR}"

print_info "Exporting package configurations to: ${EXPORT_DIR}"
echo ""

# Export Homebrew (macOS/Linux)
if command -v brew >/dev/null 2>&1; then
    print_info "Exporting Homebrew packages..."
    mkdir -p "${EXPORT_DIR}/brew"
    brew bundle dump --file="${EXPORT_DIR}/brew/Brewfile" --force
    print_success "Homebrew packages exported"
fi

# Export APT (Debian/Ubuntu)
if command -v apt >/dev/null 2>&1; then
    print_info "Exporting APT packages..."
    mkdir -p "${EXPORT_DIR}/apt"
    apt-mark showmanual > "${EXPORT_DIR}/apt/packages.txt"
    print_success "APT packages exported"
fi

# Export Pacman (Arch)
if command -v pacman >/dev/null 2>&1; then
    print_info "Exporting Pacman packages..."
    mkdir -p "${EXPORT_DIR}/pacman"
    pacman -Qqe > "${EXPORT_DIR}/pacman/packages.txt"
    print_success "Pacman packages exported"
fi

# Export pip packages
if command -v pip3 >/dev/null 2>&1 || command -v pip >/dev/null 2>&1; then
    print_info "Exporting Python packages..."
    mkdir -p "${EXPORT_DIR}/pip"
    
    # Use pip3 if available, otherwise pip
    local pip_cmd="pip"
    command -v pip3 >/dev/null 2>&1 && pip_cmd="pip3"
    
    # Export only user-installed packages (not dependencies)
    ${pip_cmd} list --user --format=freeze 2>/dev/null > "${EXPORT_DIR}/pip/requirements.txt" || \
    ${pip_cmd} freeze --user > "${EXPORT_DIR}/pip/requirements.txt" 2>/dev/null || \
    ${pip_cmd} freeze > "${EXPORT_DIR}/pip/requirements.txt"
    
    print_success "Python packages exported"
fi

# Export NPM global packages
if command -v npm >/dev/null 2>&1; then
    print_info "Exporting NPM global packages..."
    mkdir -p "${EXPORT_DIR}/npm"
    
    # List global packages, exclude npm itself
    npm list -g --depth=0 2>/dev/null | grep -v 'npm@' | tail -n +2 | \
        sed 's/├──//;s/└──//;s/ //g' | cut -d@ -f1 > "${EXPORT_DIR}/npm/packages.txt"
    
    print_success "NPM packages exported"
fi

# Export Ruby gems
if command -v gem >/dev/null 2>&1; then
    print_info "Exporting Ruby gems..."
    mkdir -p "${EXPORT_DIR}/gem"
    
    # Create a Gemfile with installed gems
    cat > "${EXPORT_DIR}/gem/Gemfile" << 'EOF'
source 'https://rubygems.org'

EOF
    
    # Add each installed gem (skip default gems)
    gem list --no-versions | tail -n +3 | while read gem_name; do
        # Skip if it's a default gem
        if ! gem list --no-versions --no-installed | grep -q "^${gem_name}$"; then
            echo "gem '${gem_name}'" >> "${EXPORT_DIR}/gem/Gemfile"
        fi
    done 2>/dev/null || true
    
    print_success "Ruby gems exported"
fi

# Export Cargo packages
if command -v cargo >/dev/null 2>&1; then
    print_info "Exporting Cargo packages..."
    mkdir -p "${EXPORT_DIR}/cargo"
    
    # List installed cargo packages
    cargo install --list | grep -E '^[a-z]' | cut -d' ' -f1 > "${EXPORT_DIR}/cargo/packages.txt"
    
    print_success "Cargo packages exported"
fi

# Export Scoop (Windows)
if command -v scoop >/dev/null 2>&1; then
    print_info "Exporting Scoop packages..."
    mkdir -p "${EXPORT_DIR}/scoop"
    scoop export > "${EXPORT_DIR}/scoop/scoopfile.json"
    print_success "Scoop packages exported"
fi

# Export Chocolatey (Windows)
if command -v choco >/dev/null 2>&1; then
    print_info "Exporting Chocolatey packages..."
    mkdir -p "${EXPORT_DIR}/choco"
    choco export > "${EXPORT_DIR}/choco/packages.config"
    print_success "Chocolatey packages exported"
fi

# Export WinGet (Windows)
if command -v winget >/dev/null 2>&1; then
    print_info "Exporting WinGet packages..."
    mkdir -p "${EXPORT_DIR}/winget"
    winget export -o "${EXPORT_DIR}/winget/packages.json"
    print_success "WinGet packages exported"
fi

# Export Snap packages (Ubuntu)
if command -v snap >/dev/null 2>&1; then
    print_info "Exporting Snap packages..."
    mkdir -p "${EXPORT_DIR}/snap"
    snap list | tail -n +2 | awk '{print $1}' > "${EXPORT_DIR}/snap/packages.txt"
    print_success "Snap packages exported"
fi

echo ""
print_success "Export complete!"
print_info "Exported configurations saved to: ${GREEN}${EXPORT_DIR}${NC}"
echo ""
print_info "To create a new machine class from this export:"
echo "  1. Review the exported files in ${EXPORT_DIR}"
echo "  2. Create a new machine directory:"
echo "     mkdir -p machine-classes/<form_factor>_<purpose>_<os>"
echo "  3. Copy the relevant package manager directories:"
echo "     cp -r ${EXPORT_DIR}/* machine-classes/<your_machine_class>/"
echo ""
print_info "Example:"
echo "  mkdir -p machine-classes/laptop_work_mac"
echo "  cp -r ${EXPORT_DIR}/* machine-classes/laptop_work_mac/"