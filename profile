#!/bin/sh

#############################################################
# Common shell setup file to be sourced from both bash or zsh
#############################################################

# Set PATH {{{
# Set local bins ahead of system PATH
export PATH=$HOME/bin:/usr/local/bin:/usr/local/sbin:$PATH
# }}}

# Editor {{{
VISUAL=nvim
if ! type $VISUAL 2> /dev/null; then
    VISUAL=vim
fi
export VISUAL
export EDITOR=$VISUAL
# }}}

# Homebrew {{{
[ -f "/home/linuxbrew/.linuxbrew/bin/brew" ] && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
# }}}

# Folding {{{
# vim:fdm=marker
# }}}

