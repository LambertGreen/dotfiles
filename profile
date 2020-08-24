#!/usr/bin/env bash

#############################################################
# Common profile setup file to be sourced from
# both bash and zsh profile.
#
# NOTE: There are cases where this file needs to be sourced
# from shell rc file e.g Emacs Tramp.
#############################################################

lgreen_setup_greeting() {
    # Only show a greeting if this is an interactive terminal
    if [ -t 1 ]; then
        export LGREEN_GREET="yes"
        echo "Welcome $(whoami), setting up your profile..."
    fi
}

lgreen_setup_profile_env() {
    # Set PATH
    # Set local bins ahead of system PATH
    export PATH=$HOME/bin:/usr/local/bin:/usr/local/sbin:$PATH

    # Editor
    export VISUAL=nvim
    export EDITOR=$VISUAL

    # BAT theme
    export BAT_THEME="TwoDark"
}

lgreen_source_os_profile() {
    if [ -z $UNAME ]; then  export UNAME=$(uname -s); fi
    if [ "$UNAME" = "Darwin" ]; then
        # shellcheck source=profile_osx
        if [ -f "$HOME/.profile_osx" ]; then
            source "$HOME/.profile_osx"
        fi
    elif [ "$UNAME" = "Linux" ]; then
        # shellcheck source=profile_linux
        if [ -f "$HOME/.profile_linux" ]; then
            source "$HOME/.profile_linux"
        fi
    fi
}

lgreen_greet_user() {
    if [ ! -z $LGREEN_GREET ]; then
        [ -x "$(command -v neofetch)" ] && neofetch || true
        echo "Profile setup complete. Happy coding."
    fi
}

#-------------------
# Main
#-------------------
# Add a variable to track that profile has been sourced
# The ./shell_common file checks for this variable to
# source this file in scenarios where it gets skipped e.g. Emacs Tramp
if [ -z $LGREEN_PROFILE_SOURCED ]; then
    export LGREEN_PROFILE_SOURCED="yes"
else
    return
fi
lgreen_setup_greeting
lgreen_setup_profile_env
lgreen_source_os_profile
lgreen_greet_user
