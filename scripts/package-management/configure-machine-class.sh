#!/usr/bin/env bash
# Configure machine class for package management system

set -euo pipefail

# Parse arguments
APPEND_MODE=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --append-to-dotfiles-env)
            APPEND_MODE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Set target file based on mode
if [[ "$APPEND_MODE" == "true" ]]; then
    MACHINE_CLASS_ENV="${HOME}/.dotfiles.env"
else
    MACHINE_CLASS_ENV="${HOME}/.dotfiles.machine.class.env"
fi

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MACHINES_DIR="${DOTFILES_ROOT}/machine-classes"

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

# Get current machine class if set
get_current_machine_class() {
    # Check unified file first
    if [[ -f "${HOME}/.dotfiles.env" ]]; then
        local machine_class=$(grep "^export DOTFILES_MACHINE_CLASS=" "${HOME}/.dotfiles.env" 2>/dev/null | cut -d'=' -f2- | tr -d '"' | tr -d "'" || echo "")
        if [[ -n "$machine_class" ]]; then
            echo "$machine_class"
            return
        fi
    fi
    
    # Fall back to separate file if it exists
    if [[ -f "${HOME}/.dotfiles.machine.class.env" ]]; then
        grep "^DOTFILES_MACHINE_CLASS=" "${HOME}/.dotfiles.machine.class.env" 2>/dev/null | cut -d'=' -f2- || echo ""
    else
        echo ""
    fi
}

# List available machine classes
list_machine_classes() {
    local machines=()
    
    for machine_dir in "${MACHINES_DIR}"/*; do
        if [[ -d "${machine_dir}" ]]; then
            local machine=$(basename "${machine_dir}")
            machines+=("${machine}")
        fi
    done
    
    echo "${machines[@]}"
}

# Display available machine classes
display_machine_classes() {
    print_info "Available machine classes:"
    echo ""
    
    local i=1
    local machines=()
    
    for machine_dir in "${MACHINES_DIR}"/*; do
        if [[ -d "${machine_dir}" ]]; then
            local machine=$(basename "${machine_dir}")
            machines+=("${machine}")
            
            # Parse machine name components
            local form_factor=$(echo "${machine}" | cut -d'_' -f1)
            local purpose=$(echo "${machine}" | cut -d'_' -f2)
            local os=$(echo "${machine}" | cut -d'_' -f3)
            
            # Format description
            local desc="${form_factor^} for ${purpose} on ${os^}"
            
            # Check what package managers this machine has
            local pms=()
            for pm_dir in "${machine_dir}"/*; do
                if [[ -d "${pm_dir}" ]]; then
                    pms+=("$(basename "${pm_dir}")")
                fi
            done
            local pm_list=$(IFS=', '; echo "${pms[*]}")
            
            printf "  %2d) %-30s - %s\n" "${i}" "${machine}" "${desc}"
            printf "      Package managers: %s\n" "${pm_list}"
            echo ""
            
            ((i++))
        fi
    done
}

# Detect likely machine class based on system
suggest_machine_class() {
    local os=""
    local form_factor=""
    local purpose="personal"  # Default assumption
    
    # Detect OS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        os="mac"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [[ -f /etc/os-release ]]; then
            source /etc/os-release
            case "${ID}" in
                ubuntu|debian) os="ubuntu" ;;
                arch|manjaro) os="arch" ;;
                *) os="linux" ;;
            esac
        fi
        
        # Check if running in WSL
        if grep -qE "(Microsoft|WSL)" /proc/version 2>/dev/null; then
            form_factor="wsl"
        fi
    elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
        os="win"
    fi
    
    # Detect form factor if not WSL
    if [[ -z "${form_factor}" ]]; then
        if [[ -f /sys/class/dmi/id/chassis_type ]]; then
            local chassis=$(cat /sys/class/dmi/id/chassis_type)
            case "${chassis}" in
                8|9|10|14) form_factor="laptop" ;;
                3|4|5|6|7) form_factor="desktop" ;;
                *) form_factor="desktop" ;;  # Default
            esac
        elif [[ "${os}" == "mac" ]]; then
            # Check if MacBook or desktop Mac
            if system_profiler SPHardwareDataType 2>/dev/null | grep -q "Book"; then
                form_factor="laptop"
            else
                form_factor="desktop"
            fi
        else
            form_factor="desktop"  # Default
        fi
    fi
    
    # Check for Docker
    if [[ -f /.dockerenv ]]; then
        form_factor="docker"
        purpose="test"
    fi
    
    echo "${form_factor}_${purpose}_${os}"
}

# Main configuration
main() {
    print_info "Package Management System - Machine Class Configuration"
    echo ""
    
    # Check current configuration
    local current_class=$(get_current_machine_class)
    if [[ -n "${current_class}" ]]; then
        print_info "Current machine class: ${GREEN}${current_class}${NC}"
        echo ""
        read -p "Do you want to change it? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_success "Configuration unchanged"
            exit 0
        fi
        echo ""
    fi
    
    # Display available machine classes
    display_machine_classes
    
    # Get list of machine classes
    IFS=' ' read -ra machines <<< "$(list_machine_classes)"
    
    # Suggest a machine class
    local suggested=$(suggest_machine_class)
    local suggested_num=0
    for i in "${!machines[@]}"; do
        if [[ "${machines[$i]}" == "${suggested}" ]]; then
            suggested_num=$((i + 1))
            break
        fi
    done
    
    if [[ ${suggested_num} -gt 0 ]]; then
        print_info "Suggested machine class based on your system: ${GREEN}${suggested}${NC} (#${suggested_num})"
        echo ""
    fi
    
    # Get user selection
    local selection=""
    while true; do
        read -p "Select machine class (1-${#machines[@]})${suggested_num:+ or press Enter for #${suggested_num}}: " selection
        
        # Use suggestion if Enter pressed and suggestion exists
        if [[ -z "${selection}" && ${suggested_num} -gt 0 ]]; then
            selection=${suggested_num}
        fi
        
        # Validate selection
        if [[ "${selection}" =~ ^[0-9]+$ ]] && (( selection >= 1 && selection <= ${#machines[@]} )); then
            break
        else
            print_error "Invalid selection. Please enter a number between 1 and ${#machines[@]}"
        fi
    done
    
    # Get selected machine class
    local selected_class="${machines[$((selection - 1))]}"
    
    print_info "Selected: ${GREEN}${selected_class}${NC}"
    echo ""
    
    # Save machine class configuration
    if [[ "$APPEND_MODE" == "true" ]]; then
        # Append to unified ~/.dotfiles.env
        echo "# Machine class for package management" >> "${MACHINE_CLASS_ENV}"
        echo "export DOTFILES_MACHINE_CLASS=${selected_class}" >> "${MACHINE_CLASS_ENV}"
        print_success "Machine class configured: ${selected_class}"
        print_info "Configuration appended to: ${MACHINE_CLASS_ENV}"
    else
        # Create separate ~/.dotfiles.machine.class.env
        cat > "${MACHINE_CLASS_ENV}" << EOF
# Package Management System - Machine Class Configuration
# Generated by package-management/scripts/configure-machine-class.sh
# Date: $(date)

# Machine class for this system
DOTFILES_MACHINE_CLASS=${selected_class}

# Package manager paths (optional overrides)
# BREW_PREFIX=/opt/homebrew
# NPM_PREFIX=/usr/local
EOF
        print_success "Machine class configured: ${selected_class}"
        print_info "Configuration saved to: ${MACHINE_CLASS_ENV}"
    fi
    echo ""
    print_info "You can now run:"
    echo "  just install-dry-run # Preview what will be installed (dry-run)"
    echo "  just install         # Install all packages for ${selected_class}"
    echo "  just update-check    # Check for updates"
    echo "  just update-all      # Update all packages"
}

# Run main
main "$@"