#!/usr/bin/env bash
# Initialize environment for package management scripts
# This ensures package managers like Homebrew are available in PATH

# Initialize Homebrew if installed
if [[ -f "/home/linuxbrew/.linuxbrew/bin/brew" ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
elif [[ -f "/opt/homebrew/bin/brew" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Initialize other package manager environments as needed
# (placeholder for future additions like cargo, etc.)