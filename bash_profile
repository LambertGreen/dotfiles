#!/usr/bin/env bash

# shellcheck source=profile
[ -f ~/.profile ] && source ~/.profile

# Source bashrc
# Needed for Ssh and Tmux hosted sessions since they only source profile
# and not bashrc.
# shellcheck source=bashrc
[ -f ~/.bashrc ] && . ~/.bashrc
