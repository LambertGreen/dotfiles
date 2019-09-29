#!/usr/bin/env bash

#############################################################
# Common shell setup file to be sourced from both bash or zsh
#############################################################

# Uncomment below to see a greeting when loading your profile
# export GREETING=1

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

 #PYENV
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
if [ -x "$(command -v pyenv)" ]; then
    eval "$(pyenv init -)"
    eval "$(pyenv virtualenv-init -)"
fi

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

if [ $GREETING ]; then
    [ -x "$(command -v neofetch)" ] && neofetch
    echo "Profile setup complete. Happy coding."
fi

# Source bashrc
# Needed for Ssh and Tmux hosted sessions since they only source profile
# and not bashrc.
[ -f ~/.bashrc ] && . ~/.bashrc
