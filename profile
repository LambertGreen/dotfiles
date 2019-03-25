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
if !type $VISUAL 2> /dev/null; then
    VISUAL=vim
fi
export VISUAL
export EDITOR=$VISUAL
# }}}

# Homebrew {{{
if [[ $(uname -s) == Linux ]]; then
    eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv)
fi
# }}}

# Development {{{
# Java {{{
# JEnv
export PATH="$HOME/.jenv/bin:$PATH"
eval "$(jenv init -)"
# }}}
# Node {{{
export NVM_DIR="$HOME/.nvm"
[ -s "/usr/local/opt/nvm/nvm.sh" ] && . "/usr/local/opt/nvm/nvm.sh"  # This loads nvm
[ -s "/usr/local/opt/nvm/etc/bash_completion" ] && . "/usr/local/opt/nvm/etc/bash_completion"  # This loads nvm bash_completion
# }}}
# Rust development {{{
# Add Rust's Cargo
export PATH="$PATH:$HOME/.cargo/bin"
# }}}
# Ruby development {{{
export PATH="$PATH:$HOME/.rvm/bin"
# }}}
# Go development {{{
export GOPATH="${HOME}/.go"
export GOROOT="$(brew --prefix golang)/libexec"
export PATH="$PATH:${GOPATH}/bin:${GOROOT}/bin"
test -d "${GOPATH}" || mkdir "${GOPATH}"
test -d "${GOPATH}/src/github.com" || mkdir -p "${GOPATH}/src/github.com"
# }}}
# Perforce
export P4CONFIG=.p4config
# }}}

# Folding {{{
# vim:fdm=marker
# }}}

