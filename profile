#!/usr/bin/env bash

#############################################################
# Common shell setup file to be sourced from both bash or zsh
#############################################################

# set OS {{{
UNAME=$(uname -s)
export UNAME
# }}}

# Set PATH {{{
# Set local bins ahead of system PATH
export PATH=$HOME/bin:/usr/local/bin:/usr/local/sbin:$PATH

# Add Cargo to path
[ -d  "$HOME/.cargo/bin" ] && export PATH="$PATH:$HOME/.cargo/bin" || true
# }}}

# Editor {{{
export VISUAL=vim
export EDITOR=$VISUAL
# }}}

# Linuxbrew {{{
if [ "$UNAME" = "Linux" ]; then
    [ -f "/home/linuxbrew/.linuxbrew/bin/brew" ] && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" || true
else
    true
fi
# }}}

# Folding {{{
# vim:fdm=marker
# }}}

