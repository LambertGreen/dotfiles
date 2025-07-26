#!/usr/bin/env bash
set -euo pipefail

# Parse command line arguments
AUTODETECT=true
while [[ $# -gt 0 ]]; do
    case $1 in
        --no-autodetect)
            AUTODETECT=false
            shift
            ;;
        *)
            echo "❌ Unknown option: $1"
            echo "Usage: $0 [--no-autodetect]"
            exit 1
            ;;
    esac
done

echo "🔧 Dotfiles Configuration"
echo ""

# Check if already configured
if [ -f .dotfiles.env ]; then
    echo "📋 Current configuration found:"
    cat .dotfiles.env
    echo ""
    read -p "Reconfigure? (y/N): " reconfigure
    if [[ ! "$reconfigure" =~ ^[Yy]$ ]]; then
        echo "✅ Using existing configuration"
        exit 0
    fi
    echo ""
fi

# Auto-detect platform if enabled
if [ "$AUTODETECT" = true ]; then
    echo "🔍 Auto-detecting platform..."
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        DETECTED_PLATFORM="osx"
        echo "✅ Detected: macOS"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/arch-release ]; then
            DETECTED_PLATFORM="arch"
            echo "✅ Detected: Arch Linux"
        elif [ -f /etc/lsb-release ] && grep -q "Ubuntu" /etc/lsb-release; then
            DETECTED_PLATFORM="ubuntu"
            echo "✅ Detected: Ubuntu Linux"
        else
            DETECTED_PLATFORM="linux"
            echo "⚠️  Detected: Linux (unknown distribution)"
        fi
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        DETECTED_PLATFORM="msys2"
        echo "✅ Detected: Windows (MSYS2/Cygwin)"
    else
        DETECTED_PLATFORM="unknown"
        echo "⚠️  Unknown platform: $OSTYPE"
    fi
    
    echo ""
fi

# Platform selection
if [ "$AUTODETECT" = true ] && [ "$DETECTED_PLATFORM" != "unknown" ] && [ "$DETECTED_PLATFORM" != "linux" ]; then
    read -p "Use detected platform ($DETECTED_PLATFORM)? (Y/n): " use_detected
    if [[ "$use_detected" =~ ^[Nn]$ ]]; then
        AUTODETECT=false
    else
        PLATFORM="$DETECTED_PLATFORM"
    fi
fi

if [ "$AUTODETECT" = false ] || [ "$DETECTED_PLATFORM" = "unknown" ] || [ "$DETECTED_PLATFORM" = "linux" ]; then
    echo "Available platforms:"
    echo "  1) osx     - macOS"
    echo "  2) arch    - Arch Linux"
    echo "  3) ubuntu  - Ubuntu Linux"
    echo "  4) msys2   - Windows with MSYS2"
    echo ""
    
    # Provide smart default for Linux
    if [ "$DETECTED_PLATFORM" = "linux" ]; then
        echo "💡 Linux detected but distribution unclear. Choose the closest match:"
    fi
    
    read -p "Select platform (1-4): " platform_choice
    
    case $platform_choice in
        1) PLATFORM="osx" ;;
        2) PLATFORM="arch" ;;
        3) PLATFORM="ubuntu" ;;
        4) PLATFORM="msys2" ;;
        *) echo "❌ Invalid choice"; exit 1 ;;
    esac
fi

echo ""
echo "Available levels:"
echo "  1) basic   - Essential shell environment"
echo "  2) typical - Basic + development tools"
echo "  3) max     - Typical + GUI applications"
echo ""
read -p "Select level (1-3): " level_choice

case $level_choice in
    1) LEVEL="basic" ;;
    2) LEVEL="typical" ;;
    3) LEVEL="max" ;;
    *) echo "❌ Invalid choice"; exit 1 ;;
esac

echo ""
echo "# Dotfiles Configuration" > .dotfiles.env
echo "# Generated on $(date)" >> .dotfiles.env
echo "export DOTFILES_PLATFORM=$PLATFORM" >> .dotfiles.env
echo "export DOTFILES_LEVEL=$LEVEL" >> .dotfiles.env

echo "✅ Configuration saved to .dotfiles.env"
echo ""
echo "📊 Your configuration:"
echo "  Platform: $PLATFORM"
echo "  Level: $LEVEL"
echo ""
echo "Next steps:"
echo "  ./bootstrap.sh  # Install tools"
echo "  just stow       # Deploy configurations"