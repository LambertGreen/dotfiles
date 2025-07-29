#!/usr/bin/env bash
# Package Management Tool
# Runtime tool for installing and updating packages based on environment variables

set -euo pipefail

# Source shared functions if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../shared/common.sh" ]; then
    source "$SCRIPT_DIR/../shared/common.sh"
fi

# Configuration
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dev/my/dotfiles}"
PLATFORM="${DOTFILES_PLATFORM:-}"
LEVEL="${DOTFILES_LEVEL:-}"

# Package lists directory
PACKAGE_DATA_DIR="$SCRIPT_DIR/data"

# Logging function
log() {
    echo "[package-mgmt] $*"
}

# Error function
error() {
    echo "[package-mgmt] ERROR: $*" >&2
    exit 1
}

# Validate environment
validate_environment() {
    if [ -z "$PLATFORM" ]; then
        error "DOTFILES_PLATFORM not set. Run: just configure"
    fi
    
    if [ -z "$LEVEL" ]; then
        error "DOTFILES_LEVEL not set. Run: just configure"
    fi
    
    if [ ! -d "$PACKAGE_DATA_DIR" ]; then
        error "Package data directory not found: $PACKAGE_DATA_DIR"
    fi
}


# Install packages for macOS
install_packages_osx() {
    local level="$1"
    
    log "Installing macOS packages for level: $level"
    
    # Install Homebrew if not present
    if ! command -v brew >/dev/null 2>&1; then
        log "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    
    # Add taps
    log "Adding Homebrew taps..."
    brew tap adoptopenjdk/openjdk || true
    brew tap buo/cask-upgrade || true
    brew tap cartr/qt4 || true
    brew tap d12frosted/emacs-plus || true
    brew tap homebrew/bundle || true
    brew tap homebrew/cask || true
    brew tap homebrew/cask-versions || true
    brew tap homebrew/cask-fonts || true
    
    # Install packages based on level
    # Basic level gets common brew packages
    if [[ "$level" =~ ^(basic|typical|max)$ ]]; then
        if [ -f "$PACKAGE_DATA_DIR/osx-basic-brew.txt" ]; then
            log "Installing basic brew packages..."
            xargs brew install < "$PACKAGE_DATA_DIR/osx-basic-brew.txt"
        fi
    fi
    
    # Typical and max get additional brew packages, cask packages, and mas packages
    if [[ "$level" =~ ^(typical|max)$ ]]; then
        if [ -f "$PACKAGE_DATA_DIR/osx-typical-brew.txt" ]; then
            log "Installing typical brew packages..."
            xargs brew install < "$PACKAGE_DATA_DIR/osx-typical-brew.txt"
        fi
        
        if [ -f "$PACKAGE_DATA_DIR/osx-typical-cask.txt" ]; then
            log "Installing typical cask packages..."
            xargs brew install --cask < "$PACKAGE_DATA_DIR/osx-typical-cask.txt"
        fi
        
        if [ -f "$PACKAGE_DATA_DIR/osx-typical-mas.txt" ]; then
            log "Installing typical Mac App Store packages..."
            if command -v mas >/dev/null 2>&1; then
                while read -r app_id; do
                    [ -n "$app_id" ] && mas install "$app_id"
                done < "$PACKAGE_DATA_DIR/osx-typical-mas.txt"
            else
                log "Warning: mas not available, skipping App Store installs"
            fi
        fi
    fi
    
    # Max gets additional packages
    if [[ "$level" == "max" ]]; then
        if [ -f "$PACKAGE_DATA_DIR/osx-max-cask.txt" ]; then
            log "Installing max cask packages..."
            xargs brew install --cask < "$PACKAGE_DATA_DIR/osx-max-cask.txt"
        fi
        
        if [ -f "$PACKAGE_DATA_DIR/osx-max-mas.txt" ]; then
            log "Installing max Mac App Store packages..."
            if command -v mas >/dev/null 2>&1; then
                while read -r app_id; do
                    [ -n "$app_id" ] && mas install "$app_id"
                done < "$PACKAGE_DATA_DIR/osx-max-mas.txt"
            else
                log "Warning: mas not available, skipping App Store installs"
            fi
        fi
    fi
    
    # Install global packages only for typical and max levels
    if [[ "$level" =~ ^(typical|max)$ ]]; then
        install_global_packages
    fi
}

# Install packages for Arch Linux
install_packages_arch() {
    local level="$1"
    
    log "Installing Arch packages for level: $level"
    
    # Update system first
    sudo pacman -Syu --noconfirm
    
    # Install basic packages for all levels
    if [[ "$level" =~ ^(basic|typical|max)$ ]]; then
        if [ -f "$PACKAGE_DATA_DIR/arch-basic-pacman.txt" ]; then
            log "Installing basic pacman packages..."
            xargs sudo pacman -S --noconfirm < "$PACKAGE_DATA_DIR/arch-basic-pacman.txt"
        fi
    fi
    
    # Typical and max levels get additional packages
    if [[ "$level" =~ ^(typical|max)$ ]]; then
        # Install yay if not present for AUR packages
        if ! command -v yay >/dev/null 2>&1; then
            log "Installing yay for AUR packages..."
            git clone https://aur.archlinux.org/yay.git /tmp/yay
            cd /tmp/yay
            makepkg -si --noconfirm
            cd -
            rm -rf /tmp/yay
        fi
        
        if [ -f "$PACKAGE_DATA_DIR/arch-typical-pacman.txt" ]; then
            log "Installing typical pacman packages..."
            xargs sudo pacman -S --noconfirm < "$PACKAGE_DATA_DIR/arch-typical-pacman.txt"
        fi
        
        if [ -f "$PACKAGE_DATA_DIR/arch-typical-aur.txt" ]; then
            log "Installing typical AUR packages..."
            xargs yay -S --noconfirm < "$PACKAGE_DATA_DIR/arch-typical-aur.txt"
        fi
    fi
    
    # Max level gets development packages
    if [[ "$level" == "max" ]]; then
        if [ -f "$PACKAGE_DATA_DIR/arch-max-pacman.txt" ]; then
            log "Installing max pacman packages..."
            xargs sudo pacman -S --noconfirm < "$PACKAGE_DATA_DIR/arch-max-pacman.txt"
        fi
    fi
    
    # Clean up package cache
    sudo pacman -Scc --noconfirm
    
    # Install global packages only for typical and max levels
    if [[ "$level" =~ ^(typical|max)$ ]]; then
        install_global_packages
    fi
}

# Install packages for Ubuntu
install_packages_ubuntu() {
    local level="$1"
    
    log "Installing Ubuntu packages for level: $level"
    
    # Update package list
    sudo apt update && sudo apt upgrade -y
    
    # Install basic packages for all levels
    if [[ "$level" =~ ^(basic|typical|max)$ ]]; then
        if [ -f "$PACKAGE_DATA_DIR/ubuntu-basic-apt.txt" ]; then
            log "Installing basic apt packages..."
            xargs sudo apt install -y < "$PACKAGE_DATA_DIR/ubuntu-basic-apt.txt"
        fi
    fi
    
    # Typical and max levels get additional packages
    if [[ "$level" =~ ^(typical|max)$ ]]; then
        # Install Homebrew if not present
        if ! command -v brew >/dev/null 2>&1; then
            log "Installing Homebrew for Linux..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            # Add brew to PATH
            eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        fi
        
        if [ -f "$PACKAGE_DATA_DIR/ubuntu-typical-apt.txt" ]; then
            log "Installing typical apt packages..."
            xargs sudo apt install -y < "$PACKAGE_DATA_DIR/ubuntu-typical-apt.txt"
        fi
        
        if [ -f "$PACKAGE_DATA_DIR/ubuntu-typical-brew.txt" ]; then
            log "Installing typical brew packages..."
            xargs brew install < "$PACKAGE_DATA_DIR/ubuntu-typical-brew.txt"
        fi
    fi
    
    # Max level gets additional packages
    if [[ "$level" == "max" ]]; then
        if [ -f "$PACKAGE_DATA_DIR/ubuntu-max-apt.txt" ]; then
            log "Installing max apt packages..."
            xargs sudo apt install -y < "$PACKAGE_DATA_DIR/ubuntu-max-apt.txt"
            # Add user to docker group
            sudo usermod -aG docker "$USER"
            log "Log out and back in for docker group to take effect"
        fi
    fi
    
    # Install global packages only for typical and max levels
    if [[ "$level" =~ ^(typical|max)$ ]]; then
        install_global_packages
    fi
}

# Install global packages (Python, Node, Ruby)
install_global_packages() {
    log "Installing global packages..."
    
    # Python packages - handle externally-managed-environment
    if command -v python3 >/dev/null 2>&1; then
        log "Installing Python packages..."
        if python3 -m pip install --upgrade pip 2>/dev/null; then
            # Regular pip install works
            python3 -m pip install black pyflakes isort pytest nose pipenv pynvim || log "Warning: Some Python packages failed to install"
        else
            # Use --break-system-packages for externally-managed environments like Arch
            log "Using --break-system-packages for externally-managed Python environment"
            python3 -m pip install --upgrade pip --break-system-packages || log "Warning: pip upgrade failed"
            python3 -m pip install black pyflakes isort pytest nose pipenv pynvim --break-system-packages || log "Warning: Some Python packages failed to install"
        fi
    fi
    
    # Node.js packages
    if command -v npm >/dev/null 2>&1; then
        log "Installing Node.js packages..."
        npm install -g typescript typescript-language-server stylelint js-beautify js-tidy prettier neovim || log "Warning: Some Node.js packages failed to install"
    fi
    
    # Ruby packages
    if command -v gem >/dev/null 2>&1; then
        log "Installing Ruby packages..."
        gem install solargraph || log "Warning: Ruby packages failed to install"
    fi
}

# Update packages for macOS
update_packages_osx() {
    log "Updating macOS packages..."
    
    if command -v brew >/dev/null 2>&1; then
        brew update
        brew upgrade
        brew cleanup
    fi
    
    if command -v mas >/dev/null 2>&1; then
        mas upgrade
    fi
    
    update_global_packages
}

# Update packages for Arch Linux
update_packages_arch() {
    log "Updating Arch packages..."
    
    if command -v yay >/dev/null 2>&1; then
        yay -Syu --noconfirm
    else
        sudo pacman -Syu --noconfirm
    fi
    
    update_global_packages
}

# Update packages for Ubuntu
update_packages_ubuntu() {
    log "Updating Ubuntu packages..."
    
    sudo apt update
    sudo apt upgrade -y
    sudo apt autoremove -y
    
    if command -v brew >/dev/null 2>&1; then
        brew update
        brew upgrade
    fi
    
    update_global_packages
}

# Update global packages
update_global_packages() {
    log "Updating global packages..."
    
    # Python packages - handle externally-managed-environment
    if command -v python3 >/dev/null 2>&1; then
        log "Updating Python packages..."
        if python3 -m pip install --upgrade pip 2>/dev/null; then
            # Regular pip install works
            python3 -m pip install --upgrade pip black pyflakes isort pytest nose pipenv pynvim || log "Warning: Some Python package updates failed"
        else
            # Use --break-system-packages for externally-managed environments like Arch
            log "Using --break-system-packages for externally-managed Python environment"
            python3 -m pip install --upgrade pip black pyflakes isort pytest nose pipenv pynvim --break-system-packages || log "Warning: Some Python package updates failed"
        fi
    fi
    
    # Node.js packages
    if command -v npm >/dev/null 2>&1; then
        log "Updating Node.js packages..."
        npm update -g || log "Warning: Node.js package updates failed"
    fi
    
    # Ruby packages
    if command -v gem >/dev/null 2>&1; then
        log "Updating Ruby packages..."
        gem update || log "Warning: Ruby package updates failed"
    fi
}

# Main install function
package_install() {
    validate_environment
    
    log "Installing packages for platform: $PLATFORM, level: $LEVEL"
    
    case "$PLATFORM" in
        osx)
            install_packages_osx "$LEVEL"
            ;;
        arch)
            install_packages_arch "$LEVEL"
            ;;
        ubuntu)
            install_packages_ubuntu "$LEVEL"
            ;;
        msys2)
            error "MSYS2 package installation not yet implemented"
            ;;
        *)
            error "Unsupported platform: $PLATFORM"
            ;;
    esac
    
    log "Package installation complete for $PLATFORM $LEVEL"
}

# Main update function
package_update() {
    validate_environment
    
    log "Updating packages for platform: $PLATFORM"
    
    case "$PLATFORM" in
        osx)
            update_packages_osx
            ;;
        arch)
            update_packages_arch
            ;;
        ubuntu)
            update_packages_ubuntu
            ;;
        msys2)
            error "MSYS2 package updates not yet implemented"
            ;;
        *)
            error "Unsupported platform: $PLATFORM"
            ;;
    esac
    
    log "Package update complete for $PLATFORM"
}

# Export functions for use as library
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script called directly
    case "${1:-}" in
        install)
            package_install
            ;;
        update)
            package_update
            ;;
        *)
            echo "Usage: $0 {install|update}"
            echo "Environment variables required: DOTFILES_PLATFORM, DOTFILES_LEVEL"
            exit 1
            ;;
    esac
fi
