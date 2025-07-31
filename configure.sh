#!/usr/bin/env bash
# Configure Script for Dotfiles Package Management
# Generates transparent ~/.dotfiles.env with explicit configuration controls

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
if [ -f ~/~/.dotfiles.env ]; then
    echo "📋 Current configuration found:"
    cat ~/~/.dotfiles.env
    echo ""
    read -p "Reconfigure? (y/N): " reconfigure
    if [[ ! "$reconfigure" =~ ^[Yy]$ ]]; then
        echo "✅ Using existing configuration"
        exit 0
    fi
    echo ""
fi

# Auto-detect platform if enabled
DETECTED_PLATFORM="unknown"
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

if [ "${PLATFORM:-}" = "" ]; then
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

# Configuration approach selection
echo "📦 Configuration Selection"
echo ""
echo "Choose configuration approach:"
echo "  1) profile - Use pre-defined configurations"
echo "  2) custom  - Select individual categories"
echo ""
read -p "Select approach (1-2): " approach_choice

case $approach_choice in
    1) USE_PROFILES=true ;;
    2) USE_PROFILES=false ;;
    *) echo "❌ Invalid choice"; exit 1 ;;
esac

echo ""

# Generate configuration
echo "# Dotfiles Configuration" > ~/.dotfiles.env
echo "# Generated on $(date)" >> ~/.dotfiles.env
echo "export DOTFILES_PLATFORM=$PLATFORM" >> ~/.dotfiles.env
echo "" >> ~/.dotfiles.env

if [ "$USE_PROFILES" = true ]; then
    # Configuration selection
    echo "Available configuration options:"
    echo ""
    echo "CLI Tools:"
    echo "  1) min-cli   - Essential shell tools only"
    echo "  2) mid-cli   - Extended CLI utilities"
    echo ""
    echo "Development:"
    echo "  3) mid-dev   - Core development environment"
    echo "  4) max-dev   - Comprehensive development tools"
    echo ""
    echo "GUI Applications:"
    echo "  5) max-gui   - Desktop applications"
    echo ""
    echo "Select options (comma-separated, e.g., '1,3' for minimal CLI + core development):"
    read -p "Choice: " area_choices
    
    # Initialize all categories as false
    CLI_MIN=false
    CLI_MID=false
    DEV_MID=false
    DEV_MAX=false
    GUI_MAX=false
    
    # Parse comma-separated choices
    IFS=',' read -ra CHOICES <<< "$area_choices"
    SELECTED_AREAS=""
    
    for choice in "${CHOICES[@]}"; do
        choice=$(echo "$choice" | tr -d ' ') # Remove spaces
        case $choice in
            1) CLI_MIN=true; SELECTED_AREAS="$SELECTED_AREAS min-cli" ;;
            2) CLI_MID=true; SELECTED_AREAS="$SELECTED_AREAS mid-cli" ;;
            3) DEV_MID=true; SELECTED_AREAS="$SELECTED_AREAS mid-dev" ;;
            4) DEV_MAX=true; SELECTED_AREAS="$SELECTED_AREAS max-dev" ;;
            5) GUI_MAX=true; SELECTED_AREAS="$SELECTED_AREAS max-gui" ;;
            *) echo "❌ Invalid choice: $choice"; exit 1 ;;
        esac
    done
    
    # Generate configuration based on selections
    echo "# Selected:$SELECTED_AREAS" >> ~/.dotfiles.env
    echo "" >> ~/.dotfiles.env
    
    # Map areas to environment variables
    # CLI areas map to CLI_UTILS
    if [ "$CLI_MIN" = true ] || [ "$CLI_MID" = true ]; then
        echo "export DOTFILES_CLI_UTILS=true" >> ~/.dotfiles.env
        if [ "$CLI_MID" = true ]; then
            echo "export DOTFILES_CLI_UTILS_HEAVY=true" >> ~/.dotfiles.env
        else
            echo "export DOTFILES_CLI_UTILS_HEAVY=false" >> ~/.dotfiles.env
        fi
    else
        echo "export DOTFILES_CLI_UTILS=false" >> ~/.dotfiles.env
        echo "export DOTFILES_CLI_UTILS_HEAVY=false" >> ~/.dotfiles.env
    fi
    
    # DEV areas map to CLI_EDITORS and DEV_ENV
    if [ "$DEV_MID" = true ] || [ "$DEV_MAX" = true ]; then
        echo "export DOTFILES_CLI_EDITORS=true" >> ~/.dotfiles.env
        echo "export DOTFILES_DEV_ENV=true" >> ~/.dotfiles.env
        if [ "$DEV_MAX" = true ]; then
            echo "export DOTFILES_CLI_EDITORS_HEAVY=true" >> ~/.dotfiles.env
            echo "export DOTFILES_DEV_ENV_HEAVY=true" >> ~/.dotfiles.env
        else
            echo "export DOTFILES_CLI_EDITORS_HEAVY=false" >> ~/.dotfiles.env
            echo "export DOTFILES_DEV_ENV_HEAVY=false" >> ~/.dotfiles.env
        fi
    else
        echo "export DOTFILES_CLI_EDITORS=false" >> ~/.dotfiles.env
        echo "export DOTFILES_DEV_ENV=false" >> ~/.dotfiles.env
        echo "export DOTFILES_CLI_EDITORS_HEAVY=false" >> ~/.dotfiles.env
        echo "export DOTFILES_DEV_ENV_HEAVY=false" >> ~/.dotfiles.env
    fi
    
    # GUI areas map to GUI_APPS
    if [ "$GUI_MAX" = true ]; then
        echo "export DOTFILES_GUI_APPS=true" >> ~/.dotfiles.env
        echo "export DOTFILES_GUI_APPS_HEAVY=true" >> ~/.dotfiles.env
    else
        echo "export DOTFILES_GUI_APPS=false" >> ~/.dotfiles.env
        echo "export DOTFILES_GUI_APPS_HEAVY=false" >> ~/.dotfiles.env
    fi
    
else
    # Custom category selection
    echo "🎛️  Custom Category Selection"
    echo "Select which P1 categories to enable:"
    echo ""
    
    # P1 Categories
    read -p "CLI_EDITORS (neovim, emacs): (Y/n): " cli_editors
    if [[ ! "$cli_editors" =~ ^[Nn]$ ]]; then
        echo "export DOTFILES_CLI_EDITORS=true" >> ~/.dotfiles.env
    else
        echo "export DOTFILES_CLI_EDITORS=false" >> ~/.dotfiles.env
    fi
    
    read -p "DEV_ENV (python, node, cmake): (Y/n): " dev_env
    if [[ ! "$dev_env" =~ ^[Nn]$ ]]; then
        echo "export DOTFILES_DEV_ENV=true" >> ~/.dotfiles.env
    else
        echo "export DOTFILES_DEV_ENV=false" >> ~/.dotfiles.env
    fi
    
    read -p "CLI_UTILS (ripgrep, fd, bat, jq): (Y/n): " cli_utils
    if [[ ! "$cli_utils" =~ ^[Nn]$ ]]; then
        echo "export DOTFILES_CLI_UTILS=true" >> ~/.dotfiles.env
    else
        echo "export DOTFILES_CLI_UTILS=false" >> ~/.dotfiles.env
    fi
    
    read -p "GUI_APPS (desktop applications): (y/N): " gui_apps
    if [[ "$gui_apps" =~ ^[Yy]$ ]]; then
        echo "export DOTFILES_GUI_APPS=true" >> ~/.dotfiles.env
    else
        echo "export DOTFILES_GUI_APPS=false" >> ~/.dotfiles.env
    fi
    
    echo ""
    echo "📈 Optional Heavy Categories (additional tools):"
    
    # Heavy Categories - only ask if base category is enabled
    if [[ ! "$cli_editors" =~ ^[Nn]$ ]]; then
        read -p "CLI_EDITORS_HEAVY (helix): (y/N): " cli_editors_p2
        if [[ "$cli_editors_p2" =~ ^[Yy]$ ]]; then
            echo "export DOTFILES_CLI_EDITORS_HEAVY=true" >> ~/.dotfiles.env
        fi
    fi
    
    if [[ ! "$dev_env" =~ ^[Nn]$ ]]; then
        read -p "DEV_ENV_HEAVY (rust, go, additional tools): (y/N): " dev_env_p2
        if [[ "$dev_env_p2" =~ ^[Yy]$ ]]; then
            echo "export DOTFILES_DEV_ENV_HEAVY=true" >> ~/.dotfiles.env
        fi
    fi
    
    if [[ ! "$cli_utils" =~ ^[Nn]$ ]]; then
        read -p "CLI_UTILS_HEAVY (additional utilities): (y/N): " cli_utils_p2
        if [[ "$cli_utils_p2" =~ ^[Yy]$ ]]; then
            echo "export DOTFILES_CLI_UTILS_HEAVY=true" >> ~/.dotfiles.env
        fi
    fi
    
    if [[ "$gui_apps" =~ ^[Yy]$ ]]; then
        read -p "GUI_APPS_HEAVY (additional desktop apps): (y/N): " gui_apps_p2
        if [[ "$gui_apps_p2" =~ ^[Yy]$ ]]; then
            echo "export DOTFILES_GUI_APPS_HEAVY=true" >> ~/.dotfiles.env
        fi
    fi
fi

# Context flags - determine work vs personal machine usage
echo ""
echo "🏢 Machine Context"
echo "These flags help filter packages appropriately for your environment:"
echo ""

read -p "Is this a work machine? (restricts to work-appropriate packages): (y/N): " is_work
if [[ "$is_work" =~ ^[Yy]$ ]]; then
    echo "export IS_WORK_MACHINE=true" >> ~/.dotfiles.env
    echo "export IS_PERSONAL_MACHINE=false" >> ~/.dotfiles.env
else
    echo "export IS_WORK_MACHINE=false" >> ~/.dotfiles.env
    
    read -p "Is this a personal machine? (enables personal/entertainment packages): (Y/n): " is_personal
    if [[ ! "$is_personal" =~ ^[Nn]$ ]]; then
        echo "export IS_PERSONAL_MACHINE=true" >> ~/.dotfiles.env
    else
        echo "export IS_PERSONAL_MACHINE=false" >> ~/.dotfiles.env
    fi
fi

echo "✅ Configuration saved to ~/.dotfiles.env"

# Create symlink for compatibility with older just versions
ln -sf ~/.dotfiles.env .env

echo ""

# Show the configuration using the package tool
echo "📊 Your configuration:"
source ~/.dotfiles.env
if [ -f "tools/package-management/package-management-config.sh" ]; then
    bash tools/package-management/package-management-config.sh show-config
else
    echo "  Platform: $PLATFORM"
    echo "  (Run package tool to see full configuration)"
fi

echo ""
echo "📋 Complete ~/.dotfiles.env configuration:"
cat ~/.dotfiles.env

echo ""
echo "Next steps:"
echo "  ./bootstrap.sh                # Install tools"
echo "  just stow                     # Deploy configurations" 
echo "  just install                  # Install packages"