#!/usr/bin/env bash

#############################################################
# Common shell setup file to be sourced from both bash or zsh
#############################################################

# set OS
UNAME=$(uname -s)
export UNAME

# Set PATH
# Set local bins ahead of system PATH
export PATH=$HOME/bin:/usr/local/bin:/usr/local/sbin:$PATH

# Editor
export VISUAL=vim
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

# Autojump
[ -f /usr/local/etc/profile.d/autojump.sh ] && . /usr/local/etc/profile.d/autojump.sh || true

# Add Cargo to path
[ -d  "$HOME/.cargo/bin" ] && export PATH="$PATH:$HOME/.cargo/bin" || true
