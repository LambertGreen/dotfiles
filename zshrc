# Use below command to performance profile this script
# Note: last line of script needs to edited as well
# zmodload zsh/zprof

#Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

HISTSIZE=1000
SAVEHIST=1000
setopt no_share_history

ZSH_THEME="agnoster"


# Which plugins would you like to load?
# Standard plugins can be found in ~/.oh-my-zsh/plugins/*
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(
   git
   colorize
)

# Source OhMyZsh
source $ZSH/oh-my-zsh.sh

# Source FZF
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Source common shell script
[ -f ~/.shell_common ] && source ~/.shell_common

# Source local config file if is present
[ -f ~/.zshrc_local ] && source ~/.zshrc_local

# The ZPlugin stuff is super slow on Windows WSL, so uncommenting for now
#--------------------------------------------
# Zplugin: https://github.com/zdharma/zplugin
# Install: sh -c "$(curl -fsSL https://raw.githubusercontent.com/zdharma/zplugin/master/doc/install.sh)"
#--------------------------------------------
# . ~/.zplugin/bin/zplugin.zsh
#
# autoload -Uz _zplugin
# (( ${+_comps} )) && _comps[zplugin]=_zplugin
#
# ZPLGM[MUTE_WARNINGS]=1
#
# zplugin light raxod502/wdx
# zplugin light zsh-users/zsh-autosuggestions
# zplugin ice blockf
# zplugin light zsh-users/zsh-completions
#
# # For GNU ls (the binaries can be gls, gdircolors)
# #
# zplugin ice atclone"dircolors -b LS_COLORS > c.zsh" atpull'%atclone' pick"c.zsh"
# zplugin light trapd00r/LS_COLORS
#
# autoload -Uz compinit
# compinit
#--------------------------------------------
# Stop performance profiler
# zprof
