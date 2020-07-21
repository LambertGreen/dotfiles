#!/usr/bin/env bash

#############################################################
# Common shell setup file to be sourced from both bash or zsh
#############################################################

# Add a variable to track that profile has been sourced
# The ./shell_common file checks for this variable to
# source this file in scenarios where it get skipped e.g. Emacs Tramp
if [ $PROFILE_SOURCED ]; then
    echo "WARNING: Profile sourced more than once!!!"
    return
fi
export PROFILE_SOURCED=1

# Only show a greeting if this is an interactive terminal
if [ -t 1 ]; then
    export GREETING=1
fi

[ $GREETING ] && echo "Welcome $(whoami), setting up your profile..."

# set OS
UNAME=$(uname -s)
export UNAME

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
