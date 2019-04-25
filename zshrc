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

#--------------------------------------------
# OhMyZsh
#--------------------------------------------
SetupOhMyZsh () {
    #Path to your oh-my-zsh installation.
    export ZSH="$HOME/.oh-my-zsh"
    ZSH_THEME="agnoster"

    # Which plugins would you like to load?
    # Standard plugins can be found in ~/.oh-my-zsh/plugins/*
    # Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
    # Example format: plugins=(rails git textmate ruby lighthouse)
    # Add wisely, as too many plugins slow down shell startup.
    plugins=(
    gitfast
    )

    source $ZSH/oh-my-zsh.sh
}

#--------------------------------------------
# FZF
#--------------------------------------------
SetupFzf() {
    [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
}

#--------------------------------------------
# Common
#--------------------------------------------
SetupCommonShell() {
    # Source common shell script
    [ -f ~/.shell_common ] && source ~/.shell_common
    # Source local config file if is present
        [ -f ~/.zshrc_local ] && source ~/.zshrc_local
}

#--------------------------------------------
# ZPlugin
#--------------------------------------------
# Zplugin: https://github.com/zdharma/zplugin
# Install: sh -c "$(curl -fsSL https://raw.githubusercontent.com/zdharma/zplugin/master/doc/install.sh)"
#--------------------------------------------
SetupZplugin() {
    . ~/.zplugin/bin/zplugin.zsh

    autoload -Uz _zplugin
    (( ${+_comps} )) && _comps[zplugin]=_zplugin

    ZPLGM[MUTE_WARNINGS]=1

    zplugin ice wait"0" blockf
    zplugin light zsh-users/zsh-completions

    zplugin ice wait"0" atload"_zsh_autosuggest_start"
    zplugin light zsh-users/zsh-autosuggestions

    # For GNU ls (the binaries can be gls, gdircolors)
    zplugin ice atclone"dircolors -b LS_COLORS > c.zsh" atpull'%atclone' pick"c.zsh"
    zplugin light trapd00r/LS_COLORS

    zplugin ice wait"0" atinit"zpcompinit; zpcdreplay"
    zplugin light zdharma/fast-syntax-highlighting

    autoload -Uz compinit
    compinit
}

SetupOhMyZsh
SetupFzf
SetupCommonShell
SetupZplugin

#--------------------------------------------
# Stop performance profiler (if enabled)
#--------------------------------------------
if [[ "$ZPROF" = true ]]; then
  zprof
fi

