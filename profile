#!/usr/bin/env bash

#############################################################
# Common shell setup file to be sourced from both bash or zsh
#############################################################

# set OS
UNAME=$(uname -s)
export UNAME

[ -v "$GREETING" ] && echo "Welcome $(whoami), setting up your profile..."

# Set PATH
# Set local bins ahead of system PATH
export PATH=$HOME/bin:/usr/local/bin:/usr/local/sbin:$PATH

# Editor
export VISUAL=nvim
export EDITOR=$VISUAL

# BAT theme
export BAT_THEME="TwoDark"

# Source OS specific profile
if [ "$UNAME" = "Linux" ]; then
    [ -f "$HOME/.profile_linux" ] && . "$HOME/.profile_linux"
else
    true
fi

if [ "$UNAME" = "Darwin" ]; then
    [ -f "$HOME/.profile_osx" ] && . "$HOME/.profile_osx"
else
    true
fi

if [ -v "$GREETING" ]; then
    echo "Setup complete. Happy coding."
    [ -x "$(command -v neofetch)" ] && neofetch
fi

# Source bashrc
# Needed for Ssh and Tmux hosted sessions since they only source profile
# and not bashrc.
[ -f ~/.bashrc ] && . ~/.bashrc
