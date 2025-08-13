#!/usr/bin/env bash
# Interactive prompts library for package management
# Provides opt-out numbered list interface with timeouts

set -euo pipefail

# Color definitions (only set if not already defined)
[[ -z "${RED:-}" ]] && readonly RED='\033[0;31m'
[[ -z "${GREEN:-}" ]] && readonly GREEN='\033[0;32m'
[[ -z "${YELLOW:-}" ]] && readonly YELLOW='\033[1;33m'
[[ -z "${BLUE:-}" ]] && readonly BLUE='\033[0;34m'
[[ -z "${CYAN:-}" ]] && readonly CYAN='\033[0;36m'
[[ -z "${MAGENTA:-}" ]] && readonly MAGENTA='\033[0;35m'
[[ -z "${NC:-}" ]] && readonly NC='\033[0m' # No Color

# Default timeout in seconds
readonly DEFAULT_TIMEOUT=15

# Print colored output (only define if not already defined)
if ! declare -f print_info >/dev/null 2>&1; then
    print_info() {
        echo -e "${BLUE}[INFO]${NC} $1"
    }
fi

if ! declare -f print_success >/dev/null 2>&1; then
    print_success() {
        echo -e "${GREEN}[SUCCESS]${NC} $1"
    }
fi

if ! declare -f print_warning >/dev/null 2>&1; then
    print_warning() {
        echo -e "${YELLOW}[WARNING]${NC} $1"
    }
fi

if ! declare -f print_error >/dev/null 2>&1; then
    print_error() {
        echo -e "${RED}[ERROR]${NC} $1"
    }
fi

if ! declare -f print_header >/dev/null 2>&1; then
    print_header() {
        echo -e "${CYAN}$1${NC}"
    }
fi

# Function to display numbered list with descriptions
display_numbered_list() {
    local title="$1"
    shift
    local items=("$@")
    
    echo -e "\n${MAGENTA}$title${NC}"
    
    local i=1
    for item in "${items[@]}"; do
        echo "  $i. $item"
        ((i++))
    done
    echo ""
}

# Function to filter items based on excluded numbers
filter_excluded_items() {
    local excluded_input="$1"
    shift
    local original_items=("$@")
    
    # Parse excluded numbers
    local excluded_numbers=()
    if [[ -n "$excluded_input" ]]; then
        # Use word splitting instead of read -a for compatibility
        excluded_numbers=($excluded_input)
    fi
    
    # Convert excluded numbers to associative array for O(1) lookup
    declare -A excluded_map
    for num in "${excluded_numbers[@]}"; do
        if [[ "$num" =~ ^[0-9]+$ ]]; then
            excluded_map["$num"]=1
        fi
    done
    
    # Return items that are not excluded
    local result=()
    local i=1
    for item in "${original_items[@]}"; do
        if [[ ! "${excluded_map[$i]:-0}" == "1" ]]; then
            result+=("$item")
        fi
        ((i++))
    done
    
    # Print result to stdout (caller can capture with command substitution)
    printf '%s\n' "${result[@]}"
}

# Main function for opt-out selection with timeout
prompt_opt_out_selection() {
    local title="$1"
    local timeout="${2:-$DEFAULT_TIMEOUT}"
    shift 2
    local items=("$@")
    
    # Display the numbered list
    display_numbered_list "$title" "${items[@]}"
    
    # Prompt for exclusions
    echo -e "${YELLOW}Enter numbers to EXCLUDE (e.g., '1 3 5' to skip items 1, 3, and 5)${NC}"
    echo -ne "${BLUE}[timeout: ${timeout}s]${NC}: "
    
    local user_input=""
    if read -t "$timeout" -r user_input; then
        if [[ -n "$user_input" ]]; then
            print_info "Excluding selected items..."
            
            # Show what was excluded
            local excluded_numbers=()
            excluded_numbers=($user_input)
            if [[ ${#excluded_numbers[@]} -gt 0 ]]; then
                echo -e "${YELLOW}Excluded:${NC}"
                for num in "${excluded_numbers[@]}"; do
                    if [[ "$num" =~ ^[0-9]+$ ]] && [[ "$num" -ge 1 ]] && [[ "$num" -le ${#items[@]} ]]; then
                        echo "  - ${items[$((num-1))]}"
                    fi
                done
            fi
            
            # Return filtered items
            filter_excluded_items "$user_input" "${items[@]}"
        else
            print_info "No exclusions specified, proceeding with all items..."
            printf '%s\n' "${items[@]}"
        fi
    else
        print_warning "No input received within ${timeout}s, proceeding with all items..."
        printf '%s\n' "${items[@]}"
    fi
    
    echo ""
}

# Function to prompt for simple yes/no with timeout
prompt_yes_no() {
    local question="$1"
    local default="$2"  # "y" or "n"
    local timeout="${3:-$DEFAULT_TIMEOUT}"
    
    local default_text=""
    if [[ "$default" == "y" ]]; then
        default_text=" [Y/n]"
    else
        default_text=" [y/N]"
    fi
    
    echo -e "${YELLOW}$question${default_text}${NC}"
    echo -ne "${BLUE}[timeout: ${timeout}s]${NC}: "
    
    local response=""
    if read -t "$timeout" -r response; then
        case "$response" in
            [Yy]|[Yy][Ee][Ss]) 
                return 0 
                ;;
            [Nn]|[Nn][Oo]) 
                return 1 
                ;;
            "") 
                # Use default
                if [[ "$default" == "y" ]]; then
                    print_info "Using default: Yes"
                    return 0
                else
                    print_info "Using default: No"
                    return 1
                fi
                ;;
            *) 
                print_warning "Invalid response, using default: $default"
                if [[ "$default" == "y" ]]; then
                    return 0
                else
                    return 1
                fi
                ;;
        esac
    else
        print_warning "No input received within ${timeout}s, using default: $default"
        if [[ "$default" == "y" ]]; then
            return 0
        else
            return 1
        fi
    fi
}

# Function to detect available package managers for the current platform
detect_available_package_managers() {
    local platform="$1"
    
    local available_pms=()
    
    case "$platform" in
        osx)
            # Check for each package manager
            command -v brew >/dev/null 2>&1 && available_pms+=("brew")
            command -v pip3 >/dev/null 2>&1 && available_pms+=("pip")
            command -v npm >/dev/null 2>&1 && available_pms+=("npm")
            command -v gem >/dev/null 2>&1 && available_pms+=("gem")
            command -v mas >/dev/null 2>&1 && available_pms+=("mas")
            ;;
        ubuntu)
            command -v apt >/dev/null 2>&1 && available_pms+=("apt")
            command -v brew >/dev/null 2>&1 && available_pms+=("brew")
            command -v pip3 >/dev/null 2>&1 && available_pms+=("pip")
            command -v npm >/dev/null 2>&1 && available_pms+=("npm")
            command -v gem >/dev/null 2>&1 && available_pms+=("gem")
            command -v snap >/dev/null 2>&1 && available_pms+=("snap")
            ;;
        arch)
            command -v pacman >/dev/null 2>&1 && available_pms+=("pacman")
            command -v yay >/dev/null 2>&1 && available_pms+=("yay")
            command -v brew >/dev/null 2>&1 && available_pms+=("brew")
            command -v pip3 >/dev/null 2>&1 && available_pms+=("pip")
            command -v npm >/dev/null 2>&1 && available_pms+=("npm")
            command -v gem >/dev/null 2>&1 && available_pms+=("gem")
            ;;
        *)
            print_error "Unknown platform: $platform"
            return 1
            ;;
    esac
    
    printf '%s\n' "${available_pms[@]}"
}

# Function to get package manager descriptions with counts
get_package_manager_descriptions() {
    local machine_class="$1"
    shift
    local pm_list=("$@")
    
    local machines_dir="${MACHINES_DIR}/${machine_class}"
    local descriptions=()
    
    for pm in "${pm_list[@]}"; do
        local desc="$pm"
        local count_info=""
        
        case "$pm" in
            brew)
                if [[ -f "${machines_dir}/brew/Brewfile" ]]; then
                    local formulae=$(grep -c '^brew ' "${machines_dir}/brew/Brewfile" 2>/dev/null)
                    local casks=$(grep -c '^cask ' "${machines_dir}/brew/Brewfile" 2>/dev/null)
                    local mas=$(grep -c '^mas ' "${machines_dir}/brew/Brewfile" 2>/dev/null)
                    [[ -z "$formulae" ]] && formulae=0
                    [[ -z "$casks" ]] && casks=0
                    [[ -z "$mas" ]] && mas=0
                    count_info=" - ${formulae} formulae, ${casks} casks, ${mas} Mac App Store apps"
                fi
                desc="brew (Homebrew)${count_info}"
                ;;
            apt)
                if [[ -f "${machines_dir}/apt/packages.txt" ]]; then
                    local count=$(grep -v '^#' "${machines_dir}/apt/packages.txt" 2>/dev/null | grep -c -v '^$')
                    [[ -z "$count" ]] && count=0
                    count_info=" - ${count} packages"
                fi
                desc="apt (Ubuntu packages)${count_info}"
                ;;
            pacman)
                if [[ -f "${machines_dir}/pacman/packages.txt" ]]; then
                    local count=$(grep -v '^#' "${machines_dir}/pacman/packages.txt" 2>/dev/null | grep -c -v '^$')
                    [[ -z "$count" ]] && count=0
                    count_info=" - ${count} packages"
                fi
                desc="pacman (Arch Linux)${count_info}"
                ;;
            pip)
                if [[ -f "${machines_dir}/pip/requirements.txt" ]]; then
                    local count=$(grep -v '^#' "${machines_dir}/pip/requirements.txt" 2>/dev/null | grep -c -v '^$')
                    [[ -z "$count" ]] && count=0
                    count_info=" - ${count} packages"
                fi
                desc="pip (Python)${count_info}"
                ;;
            npm)
                if [[ -f "${machines_dir}/npm/packages.txt" ]]; then
                    local count=$(grep -v '^#' "${machines_dir}/npm/packages.txt" 2>/dev/null | grep -c -v '^$')
                    [[ -z "$count" ]] && count=0
                    count_info=" - ${count} global packages"
                fi
                desc="npm (Node.js)${count_info}"
                ;;
            gem)
                if [[ -f "${machines_dir}/gem/Gemfile" ]]; then
                    local count=$(grep -c "^gem " "${machines_dir}/gem/Gemfile" 2>/dev/null)
                    [[ -z "$count" ]] && count=0
                    count_info=" - ${count} gems"
                fi
                desc="gem (Ruby)${count_info}"
                ;;
            mas)
                if [[ -f "${machines_dir}/brew/Brewfile" ]]; then
                    local count=$(grep -c '^mas ' "${machines_dir}/brew/Brewfile" 2>/dev/null)
                    [[ -z "$count" ]] && count=0
                    count_info=" - ${count} Mac App Store apps"
                fi
                desc="mas (Mac App Store)${count_info}"
                ;;
            *)
                desc="$pm (Package manager)"
                ;;
        esac
        
        descriptions+=("$desc")
    done
    
    printf '%s\n' "${descriptions[@]}"
}

# Example usage function (for testing)
demo_opt_out_selection() {
    local test_items=("Item One" "Item Two" "Item Three" "Item Four")
    
    echo "=== Demo: Opt-out Selection ==="
    local selected_items
    mapfile -t selected_items < <(prompt_opt_out_selection "Test Selection" 10 "${test_items[@]}")
    
    echo "Final selection:"
    for item in "${selected_items[@]}"; do
        echo "  - $item"
    done
}