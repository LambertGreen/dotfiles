#!/usr/bin/env bash
# Package Manager Detection and Selection Utilities
# Provides unified PM detection with interactive selection and timeout for unattended operation

# Detect available package managers for a given context
detect_package_managers() {
    local context="$1"  # "system", "dev", "app"
    local available_pms=()

    case "$context" in
        system)
            command -v brew >/dev/null 2>&1 && available_pms+=("brew")
            command -v apt >/dev/null 2>&1 && available_pms+=("apt")
            command -v pacman >/dev/null 2>&1 && available_pms+=("pacman")
            command -v dnf >/dev/null 2>&1 && available_pms+=("dnf")
            command -v zypper >/dev/null 2>&1 && available_pms+=("zypper")
            # Windows package managers
            command -v choco >/dev/null 2>&1 && available_pms+=("choco")
            command -v winget >/dev/null 2>&1 && available_pms+=("winget")
            ;;
        dev)
            command -v npm >/dev/null 2>&1 && available_pms+=("npm")
            command -v pip3 >/dev/null 2>&1 && available_pms+=("pip")
            command -v pipx >/dev/null 2>&1 && available_pms+=("pipx")
            command -v cargo >/dev/null 2>&1 && available_pms+=("cargo")
            command -v gem >/dev/null 2>&1 && available_pms+=("gem")
            [[ -d ~/.emacs.d ]] && available_pms+=("emacs")
            command -v nvim >/dev/null 2>&1 && available_pms+=("neovim")
            ;;
        app)
            [[ -d ~/.zinit ]] && available_pms+=("zinit")
            # Could add more app-level PMs here
            ;;
        *)
            log_error "Invalid context: $context"
            log_error "Valid contexts: system, dev, app"
            return 1
            ;;
    esac

    # Print each PM on a separate line for reliable parsing
    for pm in "${available_pms[@]}"; do
        echo "$pm"
    done
}

# Interactive selection of package managers with timeout for unattended operation
select_package_managers() {
    local context="$1"
    shift
    local available_pms=("$@")
    local selected_pms=()

    if [[ ${#available_pms[@]} -eq 0 ]]; then
        log_warn "No $context package managers detected"
        return 1
    fi

    log_debug "Detected $context package managers: ${available_pms[*]}"

    # Check if we're in truly interactive mode
    if [[ -t 0 ]] && [[ -t 1 ]]; then
        echo ""
        log_info "Select $context package managers to process:"
        echo ""

        # Show numbered list of available PMs
        for i in "${!available_pms[@]}"; do
            echo "  $((i+1)). ${available_pms[i]}"
        done
        echo ""

        log_info "Enter numbers to SELECT (e.g., '1 3' for first and third)"
        log_info "Enter 'all' or just press ENTER for all detected managers (default)"
        log_info "Enter 'none' to skip $context packages"
        log_info "Timeout: 10 seconds (defaults to 'all' for unattended operation)"
        echo ""

        # Interactive selection with timeout
        if read -t 10 -p "Selection: " selection; then
            log_debug "User input: '$selection'"

            case "$selection" in
                ""|"all")
                    selected_pms=("${available_pms[@]}")
                    log_debug "Selected all $context package managers"
                    ;;
                "none")
                    selected_pms=()
                    log_debug "Skipping $context package managers"
                    ;;
                *)
                    # Parse space-separated numbers
                    read -ra selection_numbers <<< "$selection"
                    for num in "${selection_numbers[@]}"; do
                        if [[ "$num" =~ ^[0-9]+$ ]] && [[ "$num" -ge 1 ]] && [[ "$num" -le ${#available_pms[@]} ]]; then
                            idx=$((num-1))
                            selected_pms+=("${available_pms[idx]}")
                            log_debug "Selected: ${available_pms[idx]}"
                        else
                            log_warn "Invalid selection: $num (valid range: 1-${#available_pms[@]})"
                        fi
                    done

                    if [[ ${#selected_pms[@]} -gt 0 ]]; then
                        log_debug "Selected $context package managers: ${selected_pms[*]}"
                    else
                        log_warn "No valid $context package managers selected, defaulting to all"
                        selected_pms=("${available_pms[@]}")
                    fi
                    ;;
            esac
        else
            # Timeout reached - use all for unattended operation
            echo ""  # New line after timeout
            log_debug "Timeout reached - selecting all $context package managers for unattended operation"
            selected_pms=("${available_pms[@]}")
        fi
    else
        # Non-interactive mode (CI, scripts, etc.) - select all
        log_debug "Non-interactive mode - selecting all $context package managers"
        selected_pms=("${available_pms[@]}")
    fi

    # Print each selected PM on a separate line for reliable parsing
    for pm in "${selected_pms[@]}"; do
        echo "$pm"
    done
}

# Check if a package manager requires admin privileges
pm_requires_admin() {
    local pm="$1"

    case "$pm" in
        # System PMs that typically need admin
        apt|pacman|dnf|zypper|choco)
            return 0  # true - requires admin
            ;;
        # System PMs that can work without admin
        brew|winget|scoop)
            return 1  # false - doesn't require admin
            ;;
        # Dev and app PMs typically don't need admin
        npm|pip|pipx|cargo|gem|emacs|neovim|zinit)
            return 1  # false - doesn't require admin
            ;;
        *)
            return 1  # default to not requiring admin
            ;;
    esac
}

# Separate package managers by admin requirements
separate_by_admin_requirements() {
    local selected_pms=("$@")
    local admin_pms=()
    local user_pms=()

    for pm in "${selected_pms[@]}"; do
        if pm_requires_admin "$pm"; then
            admin_pms+=("$pm")
        else
            user_pms+=("$pm")
        fi
    done

    # Return arrays as space-separated strings on separate lines
    echo "${user_pms[@]}"
    echo "${admin_pms[@]}"
}

# Display summary of PM selection
display_pm_selection_summary() {
    local context="$1"
    shift
    local selected_pms=("$@")

    if [[ ${#selected_pms[@]} -eq 0 ]]; then
        log_info "No $context package managers selected"
        return
    fi

    log_info "Processing $context package managers: ${selected_pms[*]}"
}
