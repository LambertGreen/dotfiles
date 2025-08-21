#!/usr/bin/env bash
# Package manager utilities and detection

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
        emacs)
            command -v emacs >/dev/null 2>&1
            ;;
        nvim)
            command -v nvim >/dev/null 2>&1
            ;;
        zsh)
            command -v zsh >/dev/null 2>&1
            ;;
        *)
            return 1
            ;;
    esac
}

# Get machine class configuration directory
get_machine_config_dir() {
    local pm="$1"
    local machine_class="${DOTFILES_MACHINE_CLASS}"
    local machines_dir="${DOTFILES_ROOT}/machine-classes"
    
    echo "${machines_dir}/${machine_class}/${pm}"
}

# Check if package manager has configuration
has_package_config() {
    local pm="$1"
    local config_dir=$(get_machine_config_dir "$pm")
    
    [[ -d "$config_dir" ]] && [[ -n "$(ls -A "$config_dir" 2>/dev/null)" ]]
}

# Standardized timing and execution wrapper
execute_package_manager() {
    local pm_name="$1"
    local install_function="$2"
    
    if ! check_package_manager "$pm_name"; then
        log_info "${pm_name} not available on this system, skipping"
        skipped_pms+=("$pm_name")
        return 0
    fi
    
    if ! has_package_config "$pm_name"; then
        log_info "No configuration found for ${pm_name}, skipping"
        skipped_pms+=("$pm_name")
        return 0
    fi
    
    log_output "=== Installing ${pm_name} packages ==="
    
    local start_time=$(date +%s)
    
    if $install_function; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_success "${pm_name} installation completed (${duration}s)"
        initialized_pms+=("$pm_name")
    else
        local end_time=$(date +%s) 
        local duration=$((end_time - start_time))
        log_error "${pm_name} installation failed (${duration}s)"
        failed_pms+=("$pm_name")
        return 1
    fi
    
    log_output ""
}