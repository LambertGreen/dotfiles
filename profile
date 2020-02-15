#!/usr/bin/env bash

#############################################################
# Common shell setup file to be sourced from both bash or zsh
#############################################################

# Uncomment below to see a greeting when loading your profile
export GREETING=1

# set OS
UNAME=$(uname -s)
export UNAME

[ $GREETING ] && echo "Welcome $(whoami), setting up your profile..."

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
    # shellcheck source=profile_linux
    [ -f "$HOME/.profile_linux" ] && . "$HOME/.profile_linux"
else
    true
fi

if [ "$UNAME" = "Darwin" ]; then
    # shellcheck source=profile_osx
    [ -f "$HOME/.profile_osx" ] && . "$HOME/.profile_osx"
else
    true
fi

if [ $GREETING ]; then
    [ -x "$(command -v neofetch)" ] && neofetch
    echo "Profile setup complete. Happy coding."
fi

# Source bashrc
# Needed for Ssh and Tmux hosted sessions since they only source profile
# and not bashrc.
# shellcheck source=bashrc
[ -f ~/.bashrc ] && . ~/.bashrc
