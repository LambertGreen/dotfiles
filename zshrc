#!/usr/bin/env zsh
#--------------------------------------------
# Start performance profiler (if enabled)
#--------------------------------------------
if [[ "$ZPROF" = true ]]; then
  zmodload zsh/zprof
fi

ProfileZsh() {
  shell=${1-$SHELL}
  ZPROF=true $shell -i -c exit
}

# History settings
HISTSIZE=1000
SAVEHIST=1000
setopt no_share_history

# Homebrew doctor recommends the below
umask 002

# Workaround for WSL issue:https://github.com/microsoft/WSL/issues/1887
if [ "$UNAME" = "Linux" ]; then
    if [[ "$(< /proc/version)" == *@(Microsoft|WSL)* ]]; then
        unsetopt BG_NICE
    fi
else
    true
fi

#--------------------------------------------
# OhMyZsh
#--------------------------------------------
#Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="agnoster"

SetupOhMyZsh () {

    # Which plugins would you like to load?
    # Standard plugins can be found in ~/.oh-my-zsh/plugins/*
    # Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
    # Example format: plugins=(rails git textmate ruby lighthouse)
    # Add wisely, as too many plugins slow down shell startup.
    plugins=(
        gitfast
        z
        fzf
        colored-man-pages
    )

    source $ZSH/oh-my-zsh.sh
}

#--------------------------------------------
# FZF
#--------------------------------------------
SetupFzf() {
    export FZF_BASE=$HOME/.fzf
}

#--------------------------------------------
# Common
#--------------------------------------------
SetupCommonShell() {
    # Source common shell script
    [ -f $HOME/.shell_common ] && source $HOME/.shell_common
    # Source local config file if is present
    [ -f $HOME/.zshrc_local ] && source $HOME/.zshrc_local
}

#--------------------------------------------
# ZPlugin
#--------------------------------------------
# Zplugin: https://github.com/zdharma/zplugin
# Install: sh -c "$(curl -fsSL https://raw.githubusercontent.com/zdharma/zplugin/master/doc/install.sh)"
#--------------------------------------------
SetupOhMyZshUsingZplugin() {
    setopt promptsubst

    # Git
    [[ -v "$ZPLUGIN_ICE" ]] && zplugin ice wait"0" lucid
    zplugin snippet OMZ::lib/git.zsh

    # More git?
    [[ -v "$ZPLUGIN_ICE" ]] && zplugin ice wait"0" atload"unalias grv" lucid
    zplugin snippet OMZ::plugins/git/git.plugin.zsh

    # Color man-pages
    [[ -v "$ZPLUGIN_ICE" ]] && zplugin ice wait"0" lucid
    zplugin snippet OMZ::plugins/colored-man-pages/colored-man-pages.plugin.zsh

    # Theme
    [[ -v "$ZPLUGIN_ICE" ]] && zplugin ice wait"0" lucid
    zplugin snippet OMZ::themes/agnoster.zsh-theme
}

SetupZplugin() {
    source $HOME/.zplugin/bin/zplugin.zsh

    autoload -Uz _zplugin
    (( ${+_comps} )) && _comps[zplugin]=_zplugin
    ZPLGM[MUTE_WARNINGS]=1

    # SetupOhMyZshUsingZplugin

    # [[ -v "$ZPLUGIN_ICE" ]] && zplugin ice wait"0"
    # zplugin light robbyrussell/oh-my-zsh

    [[ -v "$ZPLUGIN_ICE" ]] && zplugin ice wait"0" blockf
    zplugin light zsh-users/zsh-completions

    [[ -v "$ZPLUGIN_ICE" ]] && zplugin ice wait"0" atload"_zsh_autosuggest_start"
    zplugin light zsh-users/zsh-autosuggestions

    # Fzf-z
    zplugin light andrewferrier/fzf-z

    # For GNU ls (the binaries can be gls, gdircolors)
    [[ -v "$ZPLUGIN_ICE" ]] && zplugin ice atclone"dircolors -b LS_COLORS > c.zsh" atpull'%atclone' pick"c.zsh"
    zplugin light trapd00r/LS_COLORS

    # Syntax highlighting
    [[ -v "$ZPLUGIN_ICE" ]] && zplugin ice wait"0" atinit"zpcompinit" lucid
    zplugin light zdharma/fast-syntax-highlighting
}

SetupFzf
SetupOhMyZsh
unset ZPLUGIN_ICE
#export ZPLUGIN_ICE=1
SetupZplugin
SetupCommonShell

# Initialize completions
autoload -Uz compinit && compinit

#--------------------------------------------
# Stop performance profiler (if enabled)
#--------------------------------------------
if [[ "$ZPROF" = true ]]; then
    unset ZPROF
    zprof
fi
