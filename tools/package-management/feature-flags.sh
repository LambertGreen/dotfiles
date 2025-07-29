#!/usr/bin/env bash
# Feature Flags Configuration for Package Management
# Granular control over which tools and packages to install

set -euo pipefail

# Core system tools (always installed)
CORE_PACKAGES=(
    "git"
    "stow" 
    "curl"
    "wget"
)

# Feature flag definitions with their associated packages
declare -A FEATURE_PACKAGES

# Essential shell tools
FEATURE_PACKAGES[SHELL_TOOLS]="zsh tmux openssh-client"

# Development languages
FEATURE_PACKAGES[PYTHON]="python3 python3-pip pyenv pyenv-virtualenv black"
FEATURE_PACKAGES[NODE]="node npm"
FEATURE_PACKAGES[RUBY]="ruby rbenv"
FEATURE_PACKAGES[RUST]="rust rust-analyzer"
FEATURE_PACKAGES[JAVA]="openjdk"

# Text editors
FEATURE_PACKAGES[NEOVIM]="neovim"
FEATURE_PACKAGES[EMACS]="emacs"

# CLI utilities
FEATURE_PACKAGES[CLI_TOOLS]="ripgrep fd bat eza dust jq htop tree"
FEATURE_PACKAGES[BUILD_TOOLS]="gcc cmake ninja make"
FEATURE_PACKAGES[LANG_SERVERS]="bash-language-server ccls shellcheck"

# GUI applications  
FEATURE_PACKAGES[GUI_APPS]="firefox code"
FEATURE_PACKAGES[PRODUCTIVITY]="mas keychain"

# Specialized tools
FEATURE_PACKAGES[SECURITY]="gnupg"
FEATURE_PACKAGES[CLOUD]="awscli"
FEATURE_PACKAGES[MULTIMEDIA]="imagemagick"
FEATURE_PACKAGES[DATABASE]="postgresql"

# Work-restricted tools (keyboard/input manipulation)
FEATURE_PACKAGES[INPUT_TOOLS]="karabiner kanata"

# Fun/optional utilities
FEATURE_PACKAGES[FUN_TOOLS]="cowsay fortune"

# Default feature sets for common configurations
declare -A DEFAULT_CONFIGS

# Minimal config - just core tools
DEFAULT_CONFIGS[minimal]="SHELL_TOOLS"

# Developer config - programming tools
DEFAULT_CONFIGS[developer]="SHELL_TOOLS PYTHON NODE CLI_TOOLS NEOVIM BUILD_TOOLS LANG_SERVERS SECURITY"

# Full desktop config - everything except work-restricted
DEFAULT_CONFIGS[desktop]="SHELL_TOOLS PYTHON NODE RUBY CLI_TOOLS NEOVIM EMACS BUILD_TOOLS LANG_SERVERS GUI_APPS PRODUCTIVITY SECURITY CLOUD MULTIMEDIA DATABASE"

# Work config - desktop without input manipulation tools
DEFAULT_CONFIGS[work]="SHELL_TOOLS PYTHON NODE CLI_TOOLS NEOVIM BUILD_TOOLS LANG_SERVERS GUI_APPS PRODUCTIVITY SECURITY CLOUD"

# Personal config - everything including fun tools
DEFAULT_CONFIGS[personal]="SHELL_TOOLS PYTHON NODE RUBY RUST CLI_TOOLS NEOVIM EMACS BUILD_TOOLS LANG_SERVERS GUI_APPS PRODUCTIVITY SECURITY CLOUD MULTIMEDIA DATABASE INPUT_TOOLS FUN_TOOLS"

# Function to get enabled features from environment
get_enabled_features() {
    local features=()
    
    # Check if using a default config
    if [ -n "${DOTFILES_CONFIG:-}" ]; then
        local config_features="${DEFAULT_CONFIGS[$DOTFILES_CONFIG]:-}"
        if [ -n "$config_features" ]; then
            read -ra features <<< "$config_features"
        fi
    fi
    
    # Add individual feature flags
    for feature in "${!FEATURE_PACKAGES[@]}"; do
        local var_name="DOTFILES_${feature}"
        if [ "${!var_name:-false}" = "true" ]; then
            features+=("$feature")
        fi
    done
    
    printf '%s\n' "${features[@]}" | sort -u
}

# Function to get all packages for enabled features
get_packages_for_features() {
    local platform="$1"
    local features
    readarray -t features < <(get_enabled_features)
    
    local all_packages=("${CORE_PACKAGES[@]}")
    
    for feature in "${features[@]}"; do
        if [ -n "${FEATURE_PACKAGES[$feature]:-}" ]; then
            read -ra feature_pkgs <<< "${FEATURE_PACKAGES[$feature]}"
            all_packages+=("${feature_pkgs[@]}")
        fi
    done
    
    # Remove duplicates and sort
    printf '%s\n' "${all_packages[@]}" | sort -u
}

# Function to show current configuration
show_config() {
    echo "=== Dotfiles Package Configuration ==="
    echo "Platform: ${DOTFILES_PLATFORM:-unset}"
    echo "Config: ${DOTFILES_CONFIG:-custom}"
    echo ""
    
    echo "Enabled Features:"
    local features
    readarray -t features < <(get_enabled_features)
    
    if [ ${#features[@]} -eq 0 ]; then
        echo "  (none - only core packages will be installed)"
    else
        for feature in "${features[@]}"; do
            echo "  ✓ $feature: ${FEATURE_PACKAGES[$feature]}"
        done
    fi
    
    echo ""
    echo "Total packages to install:"
    get_packages_for_features "${DOTFILES_PLATFORM:-}"
}

# Export functions for use in package management
export -f get_enabled_features
export -f get_packages_for_features
export -f show_config