#!/usr/bin/env bash
# Configure Script for Dotfiles Environment
# Sets up platform and basic environment, then configures machine class for package management

set -euo pipefail

# Set up logging
DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${HOME}/.dotfiles/logs"
LOG_FILE="${LOG_DIR}/configure-$(date +%Y%m%d-%H%M%S).log"

# Create log directory if it doesn't exist
mkdir -p "${LOG_DIR}"

# Initialize log file with header
{
    echo "Dotfiles Configuration Log"
    echo "=========================="
    echo "Date: $(date)"
    echo "Machine: $(hostname 2>/dev/null || echo 'unknown')"
    echo "User: ${USER:-$(whoami)}"
    echo "Script: $0 $*"
    echo "=========================="
    echo ""
} > "${LOG_FILE}"

# Function to log both to console and file
log_output() {
    echo "$1" | tee -a "${LOG_FILE}"
}

# Function to log only to file (for verbose details)
log_verbose() {
    echo "$1" >> "${LOG_FILE}"
}

# Function to handle prompts with timeout and defaults
prompt_with_timeout() {
    local prompt="$1"
    local default="$2"
    local variable_name="$3"

    if read -t $PROMPT_TIMEOUT -p "$prompt" "$variable_name"; then
        # User provided input within timeout
        if [[ -z "${!variable_name}" ]]; then
            declare -g "$variable_name"="$default"
        fi
    else
        # Timeout occurred, use default
        declare -g "$variable_name"="$default"
        echo "$default"
        log_verbose "Timeout after ${PROMPT_TIMEOUT}s, using default: $default"
    fi
}

# Configurable prompt timeout - 15s for users, can be overridden for Docker
PROMPT_TIMEOUT=${DOTFILES_PROMPT_TIMEOUT:-15}

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

log_output "🔧 Dotfiles Configuration"
log_output ""

# Check if already configured
if [ -f ~/.dotfiles.env ]; then
    echo "📋 Current configuration found:"
    cat ~/.dotfiles.env
    echo ""
    prompt_with_timeout "Reconfigure? (y/N): " "N" reconfigure
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
    prompt_with_timeout "Use detected platform ($DETECTED_PLATFORM)? (Y/n): " "Y" use_detected
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

    prompt_with_timeout "Select platform (1-4): " "3" platform_choice

    case $platform_choice in
        1) PLATFORM="osx" ;;
        2) PLATFORM="arch" ;;
        3) PLATFORM="ubuntu" ;;
        4) PLATFORM="msys2" ;;
        *) echo "❌ Invalid choice"; exit 1 ;;
    esac
fi

echo ""

# Check if machine class already exists
EXISTING_MACHINE_CLASS=""
if [[ -f ~/.dotfiles.env ]]; then
    EXISTING_MACHINE_CLASS=$(grep "^export DOTFILES_MACHINE_CLASS=" ~/.dotfiles.env 2>/dev/null | cut -d'=' -f2- | tr -d '"' | tr -d "'" || echo "")
fi

if [[ -z "$EXISTING_MACHINE_CLASS" && -f ~/.dotfiles.machine.class.env ]]; then
    EXISTING_MACHINE_CLASS=$(grep "^DOTFILES_MACHINE_CLASS=" ~/.dotfiles.machine.class.env 2>/dev/null | cut -d'=' -f2- || echo "")
fi

# Configure machine class
MACHINE_CLASS=""
DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MACHINES_DIR="${DOTFILES_ROOT}/machine-classes"

if [[ -n "$EXISTING_MACHINE_CLASS" ]]; then
    echo "📋 Current machine class: $EXISTING_MACHINE_CLASS"
    prompt_with_timeout "Change machine class? (y/N): " "N" change_class
    if [[ "$change_class" =~ ^[Yy]$ ]]; then
        MACHINE_CLASS=""  # Will prompt for new one below
    else
        MACHINE_CLASS="$EXISTING_MACHINE_CLASS"
    fi
fi

# Check if machine class is pre-set (for Docker)
if [[ -n "${DOTFILES_MACHINE_CLASS:-}" ]]; then
    MACHINE_CLASS="$DOTFILES_MACHINE_CLASS"
    echo "🤖 Using pre-set machine class: $MACHINE_CLASS"
fi

if [[ -z "$MACHINE_CLASS" ]]; then
    echo ""
    echo "⚙️  Machine Class Configuration"
    echo ""

    # Display available machine classes
    echo "📋 Available machine classes:"
    echo ""

    machines=()
    i=1

    for machine_dir in "${MACHINES_DIR}"/*; do
        if [[ -d "${machine_dir}" ]]; then
            machine=$(basename "${machine_dir}")
            machines+=("${machine}")

            # Parse machine name components
            form_factor=$(echo "${machine}" | cut -d'_' -f1)
            purpose=$(echo "${machine}" | cut -d'_' -f2)
            os=$(echo "${machine}" | cut -d'_' -f3)

            # Format description
            desc="${form_factor^} for ${purpose} on ${os^}"

            # Check what package managers this machine has
            pms=()
            for pm_dir in "${machine_dir}"/*; do
                if [[ -d "${pm_dir}" ]]; then
                    pms+=("$(basename "${pm_dir}")")
                fi
            done
            pm_list=$(IFS=', '; echo "${pms[*]}")

            printf "  %2d) %-30s - %s\n" "${i}" "${machine}" "${desc}"
            printf "      Package managers: %s\n" "${pm_list}"
            echo ""

            ((i++))
        fi
    done

    # Get user selection
    selection=""
    while true; do
        prompt_with_timeout "Select machine class (1-${#machines[@]}): " "1" selection

        # Validate selection
        if [[ "${selection}" =~ ^[0-9]+$ ]] && (( selection >= 1 && selection <= ${#machines[@]} )); then
            break
        else
            echo "❌ Invalid selection. Please enter a number between 1 and ${#machines[@]}"
        fi
    done

    # Get selected machine class
    MACHINE_CLASS="${machines[$((selection - 1))]}"
    echo ""
    echo "✅ Selected machine class: $MACHINE_CLASS"
fi

# Generate unified configuration file
echo "# Dotfiles Configuration" > ~/.dotfiles.env
echo "# Generated on $(date)" >> ~/.dotfiles.env
echo "export DOTFILES_PLATFORM=$PLATFORM" >> ~/.dotfiles.env
echo "export DOTFILES_MACHINE_CLASS=$MACHINE_CLASS" >> ~/.dotfiles.env

# WSL-specific configuration
if grep -qi microsoft /proc/version 2>/dev/null || grep -qi wsl /proc/version 2>/dev/null; then
    echo "" >> ~/.dotfiles.env
    echo "# WSL-specific: Disable Windows package managers" >> ~/.dotfiles.env
    echo "# Windows packages should be managed from Windows side" >> ~/.dotfiles.env
    echo "export DOTFILES_PM_DISABLED=scoop,choco,winget" >> ~/.dotfiles.env
    log_verbose "Detected WSL environment - disabled Windows package managers"
fi

echo ""

# Show expected package managers for this machine class (informational only)
if [[ -n "$MACHINE_CLASS" ]]; then
    echo "📦 Expected Package Managers for $MACHINE_CLASS"
    echo ""

    # Find package managers defined for this machine class
    MACHINE_DIR="${MACHINES_DIR}/${MACHINE_CLASS}"

    if [[ -d "$MACHINE_DIR" ]]; then
        echo "🔍 Checking machine class configuration..."

        # Get all configured package managers for this machine class
        CONFIGURED_PMS=()
        for pm_dir in "$MACHINE_DIR"/*; do
            if [[ -d "$pm_dir" ]]; then
                pm_name=$(basename "$pm_dir")
                CONFIGURED_PMS+=("$pm_name")
            fi
        done

        if [[ ${#CONFIGURED_PMS[@]} -gt 0 ]]; then
            echo "📋 This machine class expects ${#CONFIGURED_PMS[@]} package manager(s):"
            for pm in "${CONFIGURED_PMS[@]}"; do
                echo "   • $pm"
            done
            echo ""
            echo "ℹ️  Note: Package managers will be installed during 'just install-packages'"
            echo "    After installation, run 'just register-pms' to enable/disable them"
        else
            echo "⚠️  No package managers configured for machine class: $MACHINE_CLASS"
        fi
    else
        echo "⚠️  Machine class directory not found: $MACHINE_DIR"
    fi
fi

echo ""
echo "📋 Final configuration:"
cat ~/.dotfiles.env
echo ""
echo "🎉 Configuration complete!"
echo ""
echo "Next steps:"
echo "  just bootstrap        - Install core tools (Python, stow, just, etc.)"
echo "  just stow            - Deploy configuration files"
echo "  just install-packages - Install packages"
echo "  just register-pms    - Enable/disable package managers"
echo "  just check-health    - Validate system health"

echo ""
echo "📝 Configuration session logged to: ${LOG_FILE}"

# Log final configuration to file
{
    echo ""
    echo "=== FINAL CONFIGURATION ==="
    cat ~/.dotfiles.env
    echo "==========================="
    echo ""
    echo "Configuration completed at: $(date)"
} >> "${LOG_FILE}"
