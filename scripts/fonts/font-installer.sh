#!/usr/bin/env bash
# Font Installation Tool
# Downloads and installs fonts that aren't available via package managers

set -euo pipefail

# Detect platform and set font directory
case "$OSTYPE" in
    darwin*)
        FONT_DIR="$HOME/Library/Fonts"
        PLATFORM="macos"
        ;;
    linux*)
        FONT_DIR="$HOME/.local/share/fonts"
        PLATFORM="linux"
        ;;
    msys*|cygwin*)
        # Use user fonts directory to avoid requiring admin privileges
        FONT_DIR="$HOME/AppData/Local/Microsoft/Windows/Fonts"
        PLATFORM="windows"
        ;;
    *)
        echo "❌ Unsupported platform: $OSTYPE"
        exit 1
        ;;
esac

# Ensure font directory exists
mkdir -p "$FONT_DIR"

# Function to download and install font from URL
install_font_from_url() {
    local font_name="$1"
    local download_url="$2"
    local file_pattern="${3:-*.ttf}"  # Default to TTF files
    
    echo "📦 Installing $font_name..."
    
    # Create temp directory
    local temp_dir=$(mktemp -d)
    trap "rm -rf $temp_dir" EXIT
    
    # Download font
    echo "  ⬇️  Downloading from $download_url..."
    cd "$temp_dir"
    
    if [[ "$download_url" == *.zip ]]; then
        curl -L -o font.zip "$download_url"
        unzip -q font.zip
    elif [[ "$download_url" == *.tar.gz ]]; then
        curl -L "$download_url" | tar xz
    else
        echo "  ❌ Unsupported archive format"
        return 1
    fi
    
    # Find and install font files
    local font_files=$(find . -name "$file_pattern" -type f)
    if [ -z "$font_files" ]; then
        echo "  ❌ No font files found matching pattern: $file_pattern"
        return 1
    fi
    
    echo "  📄 Found $(echo "$font_files" | wc -l) font files"
    
    # Copy fonts to font directory
    find . -name "$file_pattern" -type f -exec cp {} "$FONT_DIR/" \;
    
    echo "  ✅ Installed to $FONT_DIR"
    
    # Update font cache on Linux
    if [ "$PLATFORM" = "linux" ]; then
        echo "  🔄 Updating font cache..."
        fc-cache -fv >/dev/null 2>&1
    elif [ "$PLATFORM" = "windows" ]; then
        echo "  🔄 Font installed (restart applications to refresh cache)"
    fi
}

# Main installation logic
case "${1:-}" in
    "symbols-nerd-font")
        # Direct download for platforms without package manager support
        SYMBOLS_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/NerdFontsSymbolsOnly.zip"
        install_font_from_url "Symbols Nerd Font" "$SYMBOLS_URL" "SymbolsNerdFont*.ttf"
        ;;
        
    "aporetic-sans-mono")
        # Direct download from GitHub releases
        echo "📦 Installing Aporetic Sans Mono..."
        echo "  ⬇️  Downloading from GitHub..."
        
        # Create temp directory
        local temp_dir=$(mktemp -d)
        trap "rm -rf $temp_dir" EXIT
        
        cd "$temp_dir"
        curl -L -o aporetic.zip https://github.com/protesilaos/aporetic/archive/refs/heads/main.zip
        unzip -q aporetic.zip
        
        # Find and install the Sans Mono font files
        find aporetic-main -name "ApoSansMono*.ttf" -exec cp {} "$FONT_DIR/" \;
        
        # Update font cache on Linux
        if [ "$PLATFORM" = "linux" ]; then
            echo "  🔄 Updating font cache..."
            fc-cache -fv >/dev/null 2>&1
        elif [ "$PLATFORM" = "windows" ]; then
            echo "  🔄 Font installed (restart applications to refresh cache)"
        fi
        
        echo "  ✅ Installed to $FONT_DIR"
        ;;
        
    "iosevka-nerd-font")
        # Direct download for platforms without package manager support
        echo "📦 Installing Iosevka Nerd Font..."
        echo "  ⬇️  Downloading from GitHub..."
        curl -fLo "$FONT_DIR/IosevkaNerdFont-Regular.ttf" \
            https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/Iosevka/IosevkaNerdFont-Regular.ttf
        
        # Update font cache on Linux
        if [ "$PLATFORM" = "linux" ]; then
            echo "  🔄 Updating font cache..."
            fc-cache -fv >/dev/null 2>&1
        elif [ "$PLATFORM" = "windows" ]; then
            echo "  🔄 Font installed (restart applications to refresh cache)"
        fi
        echo "  ✅ Installed to $FONT_DIR"
        ;;
        
    "minimap")
        # Minimap font for code minimap views
        echo "📦 Installing Minimap font..."
        echo "  ⬇️  Downloading from GitHub..."
        curl -fLo "$FONT_DIR/Minimap.ttf" \
            https://github.com/davestewart/minimap-font/raw/master/src/Minimap.ttf
        
        # Update font cache on Linux
        if [ "$PLATFORM" = "linux" ]; then
            echo "  🔄 Updating font cache..."
            fc-cache -fv >/dev/null 2>&1
        elif [ "$PLATFORM" = "windows" ]; then
            echo "  🔄 Font installed (restart applications to refresh cache)"
        fi
        echo "  ✅ Installed to $FONT_DIR"
        ;;
        
    "check")
        # Check installed fonts
        echo "🔍 Checking installed fonts in $FONT_DIR..."
        echo ""
        
        check_font() {
            local pattern="$1"
            local name="$2"
            if ls "$FONT_DIR"/$pattern >/dev/null 2>&1; then
                echo "✅ $name"
            else
                echo "❌ $name"
            fi
        }
        
        case "$PLATFORM" in
            macos)
                check_font "Aporetic*.ttf" "Aporetic Sans Mono"
                check_font "SymbolsNerdFont*.ttf" "Symbols Nerd Font Mono"
                check_font "IosevkaNerdFont*.ttf" "Iosevka Nerd Font"
                check_font "Minimap.ttf" "Minimap Font"
                ;;
            linux)
                check_font "IosevkaNerdFont*.ttf" "Iosevka Nerd Font"
                check_font "SymbolsNerdFont*.ttf" "Symbols Nerd Font Mono"
                check_font "Minimap.ttf" "Minimap Font"
                ;;
            windows)
                check_font "Iosevka*NF*.ttf" "Iosevka NF variants"
                check_font "SymbolsNerdFont*.ttf" "Symbols Nerd Font Mono"
                check_font "Minimap.ttf" "Minimap Font"
                ;;
        esac
        ;;
        
    *)
        echo "Font Installation Tool"
        echo "Usage: $0 <font-name|check>"
        echo ""
        echo "Direct download fonts:"
        echo "  symbols-nerd-font    - Symbols only Nerd Font"
        echo "  iosevka-nerd-font    - Iosevka Nerd Font (for non-brew platforms)"
        echo "  minimap              - Minimap font for code minimap views"
        echo "  aporetic-sans-mono   - Aporetic Sans Mono (direct download)"
        echo ""
        echo "Commands:"
        echo "  check                - Check installed fonts"
        echo ""
        echo "Font directory: $FONT_DIR"
        ;;
esac