#!/bin/sh

#############################################################
# Common shell setup file to be sourced from both bash or zsh
#############################################################

# Set PATH {{{
# Set local bins ahead of system PATH
export PATH=$HOME/bin:/usr/local/bin:/usr/local/sbin:$PATH
# }}}

# Editor {{{
export VISUAL=vim
export EDITOR=$VISUAL
# }}}

# Homebrew {{{
[ -f "/home/linuxbrew/.linuxbrew/bin/brew" ] && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" || true
# }}}

# Folding {{{
# vim:fdm=marker
# }}}

