#!/usr/bin/env bash
# Import packages for configured machine class

set -euo pipefail

MACHINE_CLASS_ENV="${HOME}/.dotfiles.env"
DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MACHINES_DIR="${DOTFILES_ROOT}/machine-classes"
LOG_DIR="${DOTFILES_ROOT}/logs"
LOG_FILE="${LOG_DIR}/package-import-$(date +%Y%m%d-%H%M%S).log"

# Default to dry-run for safety
DRY_RUN=true
VERBOSE=false
INTERACTIVE=false

# Create log directory if it doesn't exist
mkdir -p "${LOG_DIR}"

# Initialize log file with header
{
    echo "Package Management Import Log"
    echo "============================="
    echo "Date: $(date)"
    echo "Machine: $(hostname 2>/dev/null || echo 'unknown')"
    echo "User: ${USER:-$(whoami)}"
    echo "Script: $0 $*"
    echo "============================="
    echo ""
} > "${LOG_FILE}"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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
    echo "[ERROR] $1" >> "${LOG_FILE}"
}

print_dry_run() {
    echo -e "${CYAN}[DRY-RUN]${NC} $1"
    echo "[DRY-RUN] $1" >> "${LOG_FILE}"
}

# Log command execution
log_command() {
    local cmd="$1"
    echo "" >> "${LOG_FILE}"
    echo "=================================================================================" >> "${LOG_FILE}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Executing: ${cmd}" >> "${LOG_FILE}"
    echo "=================================================================================" >> "${LOG_FILE}"
}

# Source interactive prompts library after basic functions are defined
source "${DOTFILES_ROOT}/scripts/package-management/interactive-prompts.sh"

# Execute command with logging
execute_with_log() {
    local cmd="$1"
    log_command "${cmd}"
    
    # Execute and capture output
    if eval "${cmd}" >> "${LOG_FILE}" 2>&1; then
        echo "[SUCCESS] Command completed successfully" >> "${LOG_FILE}"
        return 0
    else
        local exit_code=$?
        echo "[FAILED] Command failed with exit code: ${exit_code}" >> "${LOG_FILE}"
        return ${exit_code}
    fi
}

# Load machine class configuration
load_machine_class() {
    if [[ -f "${MACHINE_CLASS_ENV}" ]]; then
        source "${MACHINE_CLASS_ENV}"
    else
        print_error "Machine class not configured. Run: ./package-management/scripts/configure-machine-class.sh"
        exit 1
    fi
    
    if [[ -z "${DOTFILES_MACHINE_CLASS:-}" ]]; then
        print_error "DOTFILES_MACHINE_CLASS not set in ${MACHINE_CLASS_ENV}"
        exit 1
    fi
    
    echo "${DOTFILES_MACHINE_CLASS}"
}

# Check if package manager is available
check_package_manager() {
    local pm="$1"
    
    case "${pm}" in
        brew)
            command -v brew >/dev/null 2>&1
            ;;
        apt)
            command -v apt >/dev/null 2>&1
            ;;
        pacman)
            command -v pacman >/dev/null 2>&1
            ;;
        pip)
            command -v pip3 >/dev/null 2>&1 || command -v pip >/dev/null 2>&1
            ;;
        npm)
            command -v npm >/dev/null 2>&1
            ;;
        gem)
            command -v gem >/dev/null 2>&1
            ;;
        cargo)
            command -v cargo >/dev/null 2>&1
            ;;
        scoop)
            command -v scoop >/dev/null 2>&1
            ;;
        choco)
            command -v choco >/dev/null 2>&1
            ;;
        winget)
            command -v winget >/dev/null 2>&1
            ;;
        snap)
            command -v snap >/dev/null 2>&1
            ;;
        *)
            return 1
            ;;
    esac
}

# Preview what will be installed
preview_packages() {
    local pm="$1"
    local pm_dir="$2"
    
    print_info "Packages to install via ${GREEN}${pm}${NC}:"
    
    case "${pm}" in
        brew)
            if [[ -f "${pm_dir}/Brewfile" ]]; then
                # Check what's missing or outdated
                echo "  Checking Brewfile status..."
                if brew bundle check --file="${pm_dir}/Brewfile" >/dev/null 2>&1; then
                    echo "  ✓ All packages from Brewfile are already installed"
                else
                    echo "  Packages to be installed/updated:"
                    # Show what's in the Brewfile
                    grep '^brew ' "${pm_dir}/Brewfile" 2>/dev/null | sed 's/brew "\(.*\)".*/    - \1/' | head -10
                    local brew_count=$(grep -c '^brew ' "${pm_dir}/Brewfile" 2>/dev/null || echo 0)
                    [[ ${brew_count} -gt 10 ]] && echo "    ... and $((brew_count - 10)) more formulae"
                    
                    if grep -q '^cask ' "${pm_dir}/Brewfile" 2>/dev/null; then
                        echo "  Casks:"
                        grep '^cask ' "${pm_dir}/Brewfile" | sed 's/cask "\(.*\)".*/    - \1/' | head -5
                        local cask_count=$(grep -c '^cask ' "${pm_dir}/Brewfile" 2>/dev/null || echo 0)
                        [[ ${cask_count} -gt 5 ]] && echo "    ... and $((cask_count - 5)) more"
                    fi
                fi
            else
                print_warning "  No Brewfile found"
            fi
            ;;
            
        apt|pacman)
            if [[ -f "${pm_dir}/packages.txt" ]]; then
                local packages=$(grep -v '^#' "${pm_dir}/packages.txt" | grep -v '^$' | head -20)
                echo "${packages}" | sed 's/^/    - /'
                local total=$(grep -v '^#' "${pm_dir}/packages.txt" | grep -c -v '^$')
                [[ ${total} -gt 20 ]] && echo "    ... and $((total - 20)) more"
            else
                print_warning "  No packages.txt found"
            fi
            ;;
            
        pip)
            if [[ -f "${pm_dir}/requirements.txt" ]]; then
                local packages=$(grep -v '^#' "${pm_dir}/requirements.txt" | grep -v '^$' | head -15)
                echo "${packages}" | sed 's/^/    - /'
                local total=$(grep -v '^#' "${pm_dir}/requirements.txt" | grep -c -v '^$')
                [[ ${total} -gt 15 ]] && echo "    ... and $((total - 15)) more"
            else
                print_warning "  No requirements.txt found"
            fi
            ;;
            
        npm)
            if [[ -f "${pm_dir}/packages.txt" ]]; then
                local packages=$(grep -v '^#' "${pm_dir}/packages.txt" | grep -v '^$' | head -15)
                echo "${packages}" | sed 's/^/    - /'
                local total=$(grep -v '^#' "${pm_dir}/packages.txt" | grep -c -v '^$')
                [[ ${total} -gt 15 ]] && echo "    ... and $((total - 15)) more"
            else
                print_warning "  No packages.txt found"
            fi
            ;;
            
        gem)
            if [[ -f "${pm_dir}/Gemfile" ]]; then
                local gems=$(grep "^gem " "${pm_dir}/Gemfile" | sed "s/gem '\(.*\)'.*/    - \1/" | head -10)
                echo "${gems}"
                local total=$(grep -c "^gem " "${pm_dir}/Gemfile")
                [[ ${total} -gt 10 ]] && echo "    ... and $((total - 10)) more"
            else
                print_warning "  No Gemfile found"
            fi
            ;;
            
        *)
            print_warning "  Preview not implemented for ${pm}"
            ;;
    esac
    echo ""
}

# Show the install command for a package manager (for verbose dry-run)
show_install_command() {
    local pm="$1"
    local pm_dir="$2"
    
    case "${pm}" in
        brew)
            if [[ -f "${pm_dir}/Brewfile" ]]; then
                echo "  $ brew bundle install --file=\"${pm_dir}/Brewfile\" --no-upgrade"
                echo ""
                echo "  Note: Homebrew doesn't have true dry-run. To check what would be installed:"
                echo "  $ brew bundle check --file=\"${pm_dir}/Brewfile\" --verbose"
            fi
            ;;
        apt)
            [[ -f "${pm_dir}/packages.txt" ]] && echo "  $ while read package; do sudo apt-get install -y \$package; done < \"${pm_dir}/packages.txt\""
            ;;
        pacman)
            [[ -f "${pm_dir}/packages.txt" ]] && echo "  $ while read package; do sudo pacman -S --needed --noconfirm \$package; done < \"${pm_dir}/packages.txt\""
            ;;
        pip)
            if [[ -f "${pm_dir}/requirements.txt" ]]; then
                local pip_cmd="pip3"
                command -v pip3 >/dev/null 2>&1 || pip_cmd="pip"
                # Handle externally-managed environments (PEP 668) on macOS/Homebrew
                local pip_flags="--user"
                if [[ "$OSTYPE" == "darwin"* ]] && command -v brew >/dev/null 2>&1; then
                    pip_flags="--user --break-system-packages"
                fi
                echo "  $ ${pip_cmd} install ${pip_flags} -r \"${pm_dir}/requirements.txt\""
            fi
            ;;
        npm)
            [[ -f "${pm_dir}/packages.txt" ]] && echo "  $ while read pkg; do npm install -g \"\$pkg\"; done < \"${pm_dir}/packages.txt\""
            ;;
        gem)
            [[ -f "${pm_dir}/Gemfile" ]] && echo "  $ cd \"${pm_dir}\" && bundle install"
            ;;
        *)
            echo "  $ # Command display not implemented for ${pm}"
            ;;
    esac
}

# Install packages for a specific package manager
install_packages() {
    local pm="$1"
    local pm_dir="$2"
    
    if [[ "${DRY_RUN}" == true ]]; then
        print_dry_run "Would install ${pm} packages from ${pm_dir}"
        preview_packages "${pm}" "${pm_dir}"
        
        # Show commands in verbose dry-run mode
        if [[ "${VERBOSE}" == true ]]; then
            echo ""
            print_info "Command that would be executed:"
            show_install_command "${pm}" "${pm_dir}"
        fi
        return 0
    fi
    
    print_info "Installing ${pm} packages..."
    
    case "${pm}" in
        brew)
            if [[ -f "${pm_dir}/Brewfile" ]]; then
                # First check what's outdated before installing
                print_info "Checking for Homebrew package updates..."
                log_command "brew outdated"
                if outdated_before=$(brew outdated 2>&1); then
                    if [[ -n "$outdated_before" ]]; then
                        echo "[PRE-INSTALL] Outdated packages before install:" >> "${LOG_FILE}"
                        echo "$outdated_before" >> "${LOG_FILE}"
                    else
                        echo "[PRE-INSTALL] No outdated packages before install" >> "${LOG_FILE}"
                    fi
                fi
                
                local cmd="brew bundle install --file=\"${pm_dir}/Brewfile\" --no-upgrade"
                execute_with_log "${cmd}"
                
                # Check what got installed/upgraded
                log_command "brew outdated (post-install)"
                if outdated_after=$(brew outdated 2>&1); then
                    if [[ -n "$outdated_after" ]]; then
                        echo "[POST-INSTALL] Still outdated after install:" >> "${LOG_FILE}"
                        echo "$outdated_after" >> "${LOG_FILE}"
                    else
                        echo "[POST-INSTALL] All packages up to date after install" >> "${LOG_FILE}"
                    fi
                fi
                
                # Check for sudo-required casks
                if [[ -f "${pm_dir}/Brewfile.casks-sudo" ]]; then
                    print_warning "Sudo-required casks found in Brewfile.casks-sudo"
                    print_info "Run separately: just install-brew-sudo"
                fi
            else
                print_warning "No Brewfile found"
            fi
            ;;
            
        apt)
            if [[ -f "${pm_dir}/packages.txt" ]]; then
                print_info "Installing APT packages (may require sudo)..."
                # Use while loop instead of xargs for better Docker compatibility
                while IFS= read -r package || [[ -n "$package" ]]; do
                    # Skip empty lines and comments
                    [[ -z "$package" || "$package" =~ ^[[:space:]]*# ]] && continue
                    # Remove inline comments and trim trailing whitespace
                    package="${package%%#*}"
                    package="${package%"${package##*[![:space:]]}"}"
                    [[ -z "$package" ]] && continue
                    print_info "Installing apt package: $package"
                    sudo apt-get install -y "$package"
                done < "${pm_dir}/packages.txt"
            else
                print_warning "No packages.txt found"
            fi
            ;;
            
        pacman)
            if [[ -f "${pm_dir}/packages.txt" ]]; then
                print_info "Installing Pacman packages (may require sudo)..."
                # Use while loop instead of xargs for better Docker compatibility
                while IFS= read -r package || [[ -n "$package" ]]; do
                    # Skip empty lines and comments
                    [[ -z "$package" || "$package" =~ ^[[:space:]]*# ]] && continue
                    # Remove inline comments and trim trailing whitespace
                    package="${package%%#*}"
                    package="${package%"${package##*[![:space:]]}"}"
                    [[ -z "$package" ]] && continue
                    print_info "Installing pacman package: $package"
                    sudo pacman -S --needed --noconfirm "$package"
                done < "${pm_dir}/packages.txt"
            else
                print_warning "No packages.txt found"
            fi
            ;;
            
        pip)
            if [[ -f "${pm_dir}/requirements.txt" ]]; then
                local pip_cmd="pip3"
                command -v pip3 >/dev/null 2>&1 || pip_cmd="pip"
                # Handle externally-managed environments (PEP 668) on macOS/Homebrew
                local pip_flags="--user"
                if [[ "$OSTYPE" == "darwin"* ]] && command -v brew >/dev/null 2>&1; then
                    pip_flags="--user --break-system-packages"
                fi
                
                # Check what's outdated before installing
                print_info "Checking for pip package updates..."
                log_command "${pip_cmd} list --outdated"
                if outdated_pip_before=$(${pip_cmd} list --outdated --user 2>/dev/null || ${pip_cmd} list --outdated 2>/dev/null); then
                    if [[ -n "$outdated_pip_before" ]] && [[ $(echo "$outdated_pip_before" | wc -l) -gt 2 ]]; then
                        echo "[PRE-INSTALL] Outdated pip packages before install:" >> "${LOG_FILE}"
                        echo "$outdated_pip_before" >> "${LOG_FILE}"
                    else
                        echo "[PRE-INSTALL] No outdated pip packages before install" >> "${LOG_FILE}"
                    fi
                fi
                
                local cmd="${pip_cmd} install ${pip_flags} -r \"${pm_dir}/requirements.txt\""
                execute_with_log "${cmd}"
                
                # Check what's still outdated after installing
                log_command "${pip_cmd} list --outdated (post-install)"
                if outdated_pip_after=$(${pip_cmd} list --outdated --user 2>/dev/null || ${pip_cmd} list --outdated 2>/dev/null); then
                    if [[ -n "$outdated_pip_after" ]] && [[ $(echo "$outdated_pip_after" | wc -l) -gt 2 ]]; then
                        echo "[POST-INSTALL] Still outdated pip packages after install:" >> "${LOG_FILE}"
                        echo "$outdated_pip_after" >> "${LOG_FILE}"
                    else
                        echo "[POST-INSTALL] All pip packages up to date after install" >> "${LOG_FILE}"
                    fi
                fi
            else
                print_warning "No requirements.txt found"
            fi
            ;;
            
        npm)
            if [[ -f "${pm_dir}/packages.txt" ]]; then
                while IFS= read -r package; do
                    [[ -z "${package}" || "${package}" =~ ^# ]] && continue
                    npm install -g "${package}"
                done < "${pm_dir}/packages.txt"
            else
                print_warning "No packages.txt found"
            fi
            ;;
            
        gem)
            if [[ -f "${pm_dir}/Gemfile" ]]; then
                # Install bundler if not present
                gem list bundler -i >/dev/null 2>&1 || gem install --no-document bundler
                
                cd "${pm_dir}"
                bundle install
                cd - >/dev/null
            else
                print_warning "No Gemfile found"
            fi
            ;;
            
        cargo)
            if [[ -f "${pm_dir}/packages.txt" ]]; then
                while IFS= read -r package; do
                    [[ -z "${package}" || "${package}" =~ ^# ]] && continue
                    cargo install "${package}"
                done < "${pm_dir}/packages.txt"
            else
                print_warning "No packages.txt found"
            fi
            ;;
            
        scoop)
            if [[ -f "${pm_dir}/scoopfile.json" ]]; then
                scoop import "${pm_dir}/scoopfile.json"
            else
                print_warning "No scoopfile.json found"
            fi
            ;;
            
        choco)
            if [[ -f "${pm_dir}/packages.config" ]]; then
                # Chocolatey has --whatif flag for dry-run
                choco install "${pm_dir}/packages.config" -y
            else
                print_warning "No packages.config found"
            fi
            ;;
            
        winget)
            if [[ -f "${pm_dir}/packages.json" ]]; then
                winget import --import-file "${pm_dir}/packages.json"
            else
                print_warning "No packages.json found"
            fi
            ;;
            
        snap)
            if [[ -f "${pm_dir}/packages.txt" ]]; then
                while IFS= read -r package; do
                    [[ -z "${package}" || "${package}" =~ ^# ]] && continue
                    sudo snap install "${package}"
                done < "${pm_dir}/packages.txt"
            else
                print_warning "No packages.txt found"
            fi
            ;;
            
        *)
            print_warning "Unknown package manager: ${pm}"
            ;;
    esac
}

# Determine package manager order based on OS
get_package_manager_order() {
    local machine_class="$1"
    local os=$(echo "${machine_class}" | cut -d'_' -f3)
    
    case "${os}" in
        mac)
            echo "brew pip npm gem cargo"
            ;;
        ubuntu)
            echo "apt brew pip npm gem cargo snap"
            ;;
        arch)
            echo "pacman pip npm gem cargo"
            ;;
        win)
            echo "scoop choco winget pip npm"
            ;;
        *)
            # Default order - system PMs first, then language PMs
            echo "apt pacman brew scoop choco pip npm gem cargo"
            ;;
    esac
}

# Main import function
main() {
    local machine_class=$(load_machine_class)
    local machine_dir="${MACHINES_DIR}/${machine_class}"
    
    if [[ ! -d "${machine_dir}" ]]; then
        print_error "Machine class directory not found: ${machine_dir}"
        exit 1
    fi
    
    print_info "Machine class: ${GREEN}${machine_class}${NC}"
    
    if [[ "${DRY_RUN}" == true ]]; then
        print_dry_run "Preview mode - no packages will be installed"
    fi
    echo ""
    
    # Get package manager order
    local pm_order=$(get_package_manager_order "${machine_class}")
    
    # Track what we'll install
    local available_pms=()
    local unavailable_pms=()
    local configured_pms=()
    
    # Check what's available and configured
    for pm in ${pm_order}; do
        local pm_dir="${machine_dir}/${pm}"
        
        # Skip if no config for this PM
        if [[ ! -d "${pm_dir}" ]]; then
            continue
        fi
        
        configured_pms+=("${pm}")
        
        # Check if PM is available
        if check_package_manager "${pm}"; then
            available_pms+=("${pm}")
        else
            unavailable_pms+=("${pm}")
        fi
    done
    
    # Show summary
    print_info "Package managers configured: ${configured_pms[*]}"
    if [[ ${#available_pms[@]} -gt 0 ]]; then
        print_success "Available on this system: ${available_pms[*]}"
    fi
    if [[ ${#unavailable_pms[@]} -gt 0 ]]; then
        print_warning "Not available on this system: ${unavailable_pms[*]}"
    fi
    echo ""
    
    # Interactive package manager selection if requested
    local selected_pms=("${available_pms[@]}")
    if [[ "${INTERACTIVE}" == true ]] && [[ ${#available_pms[@]} -gt 0 ]]; then
        print_header "📦 Interactive Package Manager Selection"
        echo ""
        
        # Get descriptions with package counts
        local pm_descriptions=()
        for pm in "${available_pms[@]}"; do
            local desc="$pm"
            case "$pm" in
                brew)
                    if [[ -f "${machine_dir}/brew/Brewfile" ]]; then
                        local formulae=$(grep -c '^brew ' "${machine_dir}/brew/Brewfile" 2>/dev/null || echo 0)
                        local casks=$(grep -c '^cask ' "${machine_dir}/brew/Brewfile" 2>/dev/null || echo 0)
                        desc="brew (Homebrew) - ${formulae} formulae, ${casks} casks"
                    fi
                    ;;
                pip)
                    if [[ -f "${machine_dir}/pip/requirements.txt" ]]; then
                        local count=$(grep -v '^#' "${machine_dir}/pip/requirements.txt" 2>/dev/null | grep -c -v '^$' || echo 0)
                        desc="pip (Python) - ${count} packages"
                    fi
                    ;;
                npm)
                    if [[ -f "${machine_dir}/npm/packages.txt" ]]; then
                        local count=$(grep -v '^#' "${machine_dir}/npm/packages.txt" 2>/dev/null | grep -c -v '^$' || echo 0)
                        desc="npm (Node.js) - ${count} packages"
                    fi
                    ;;
            esac
            pm_descriptions+=("$desc")
        done
        
        # Display the numbered list
        display_numbered_list "Package managers to install:" "${pm_descriptions[@]}"
        
        # Prompt for exclusions
        echo -e "${YELLOW}Enter numbers to EXCLUDE (e.g., '2' to skip pip)${NC}"
        echo -ne "${BLUE}[timeout: 15s]${NC}: "
        
        local user_input=""
        if read -t 15 -r user_input; then
            if [[ -n "$user_input" ]]; then
                # Parse excluded numbers and filter PMs
                local excluded_nums=()
                read -ra excluded_nums <<< "$user_input"
                
                local final_pms=()
                local i=1
                for pm in "${available_pms[@]}"; do
                    local excluded=false
                    for num in "${excluded_nums[@]}"; do
                        if [[ "$num" == "$i" ]]; then
                            excluded=true
                            echo -e "${YELLOW}Excluding: ${pm_descriptions[$((i-1))]}${NC}"
                            break
                        fi
                    done
                    if [[ "$excluded" != true ]]; then
                        final_pms+=("$pm")
                    fi
                    ((i++))
                done
                selected_pms=("${final_pms[@]}")
            fi
        else
            print_warning "No input received within 15s, proceeding with all package managers..."
        fi
        
        if [[ ${#selected_pms[@]} -eq 0 ]]; then
            print_warning "No package managers selected, exiting..."
            return 0
        fi
        
        print_info "Selected package managers: ${selected_pms[*]}"
        echo ""
    fi
    
    # Install packages in order
    for pm in ${pm_order}; do
        local pm_dir="${machine_dir}/${pm}"
        
        # Skip if no config for this PM
        if [[ ! -d "${pm_dir}" ]]; then
            continue
        fi
        
        # Skip if not in selected PMs (interactive mode)
        if [[ "${INTERACTIVE}" == true ]]; then
            local pm_selected=false
            for selected_pm in "${selected_pms[@]}"; do
                if [[ "$pm" == "$selected_pm" ]]; then
                    pm_selected=true
                    break
                fi
            done
            if [[ "$pm_selected" != true ]]; then
                continue
            fi
        fi
        
        # Check if PM is available
        if check_package_manager "${pm}"; then
            install_packages "${pm}" "${pm_dir}"
            if [[ "${DRY_RUN}" == false ]]; then
                print_success "${pm} packages installed"
                echo ""
            fi
        else
            if [[ "${DRY_RUN}" == true ]]; then
                print_warning "Would skip ${pm} (not available)"
                echo ""
            fi
        fi
    done
    
    # Summary
    echo ""
    if [[ "${DRY_RUN}" == false ]]; then
        print_success "Package import complete!"
        
        if [[ ${#available_pms[@]} -gt 0 ]]; then
            print_info "Installed from: ${available_pms[*]}"
        fi
        
        if [[ ${#unavailable_pms[@]} -gt 0 ]]; then
            print_warning "Skipped (not available): ${unavailable_pms[*]}"
        fi
        
        print_info "Full log available at: ${LOG_FILE}"
    else
        echo "[DRY-RUN] Session logged to: ${LOG_FILE}" >> "${LOG_FILE}"
    fi
}

# Show usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Import packages for the configured machine class.
By default, runs in dry-run mode to preview what will be installed.

OPTIONS:
    --install           Actually install packages (disable dry-run)
    --pm <name>         Only install packages for specific package manager
    --verbose           Show detailed output
    --help              Show this help message

EXAMPLES:
    $0                  Preview what will be installed (dry-run)
    $0 --install        Install all packages
    $0 --install --pm brew   Install only Homebrew packages
    $0 --pm pip         Preview only pip packages

SUPPORTED PACKAGE MANAGERS:
    brew, apt, pacman, pip, npm, gem, cargo, scoop, choco, winget, snap

EOF
}

# Parse arguments
SPECIFIC_PM=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --install)
            DRY_RUN=false
            shift
            ;;
        --interactive)
            INTERACTIVE=true
            shift
            ;;
        --pm)
            SPECIFIC_PM="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# If specific PM requested, only handle that
if [[ -n "${SPECIFIC_PM}" ]]; then
    machine_class=$(load_machine_class)
    machine_dir="${MACHINES_DIR}/${machine_class}"
    pm_dir="${machine_dir}/${SPECIFIC_PM}"
    
    print_info "Machine class: ${GREEN}${machine_class}${NC}"
    
    if [[ "${DRY_RUN}" == true ]]; then
        print_dry_run "Preview mode for ${SPECIFIC_PM}"
    fi
    echo ""
    
    if [[ ! -d "${pm_dir}" ]]; then
        print_error "No configuration for ${SPECIFIC_PM} in machine class ${machine_class}"
        exit 1
    fi
    
    if check_package_manager "${SPECIFIC_PM}"; then
        install_packages "${SPECIFIC_PM}" "${pm_dir}"
        if [[ "${DRY_RUN}" == false ]]; then
            print_success "${SPECIFIC_PM} packages installed"
        fi
    else
        print_error "${SPECIFIC_PM} not available on this system"
        exit 1
    fi
else
    # Run full import
    main
fi