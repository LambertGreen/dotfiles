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
        z
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
SetupOhMyZshUsingZplugin() {
    setopt promptsubst

    # Git
    zplugin snippet OMZ::lib/git.zsh
    zplugin snippet OMZ::plugins/git/git.plugin.zsh

    # Color man-pages
    zplugin snippet OMZ::plugins/colored-man-pages/colored-man-pages.plugin.zsh

    # Theme
    zplugin snippet OMZ::themes/agnoster.zsh-theme
}

SetupOhMyZshUsingZpluginTurbo() {
    setopt promptsubst

    # Git
    zplugin ice wait"0" lucid
    zplugin snippet OMZ::lib/git.zsh

    # More git?
    zplugin ice wait"0" atload"unalias grv" lucid
    zplugin snippet OMZ::plugins/git/git.plugin.zsh

    # Color man-pages
    zplugin ice wait"0" lucid
    zplugin snippet OMZ::plugins/colored-man-pages/colored-man-pages.plugin.zsh

    # Theme
    zplugin ice wait"0" lucid
    zplugin snippet OMZ::themes/agnoster.zsh-theme
}

SetupZplugin() {
    . ~/.zplugin/bin/zplugin.zsh

    autoload -Uz _zplugin
    (( ${+_comps} )) && _comps[zplugin]=_zplugin
    ZPLGM[MUTE_WARNINGS]=1

    #SetupOhMyZshUsingZplugin
    zplugin light zsh-users/zsh-completions
    zplugin light zsh-users/zsh-autosuggestions
    zplugin light zdharma/fast-syntax-highlighting

    # Fzf
    zplugin ice from"gh-r" as"program"; zplugin load junegunn/fzf-bin
    # Fzf-z
    zplugin light andrewferrier/fzf-z

    # For GNU ls (the binaries can be gls, gdircolors)
    zplugin ice atclone"dircolors -b LS_COLORS > c.zsh" atpull'%atclone' pick"c.zsh"
    zplugin light trapd00r/LS_COLORS
}

SetupZpluginTurbo() {
    . ~/.zplugin/bin/zplugin.zsh

    autoload -Uz _zplugin
    (( ${+_comps} )) && _comps[zplugin]=_zplugin

    ZPLGM[MUTE_WARNINGS]=1

    #SetupOhMyZshUsingZplugin

    zplugin ice wait"0" blockf
    zplugin light zsh-users/zsh-completions

    zplugin ice wait"0" atload"_zsh_autosuggest_start"
    zplugin light zsh-users/zsh-autosuggestions

    # Fzf
    zplugin ice from"gh-r" as"program"; zplugin load junegunn/fzf-bin
    # Fzf-z

    zplugin light andrewferrier/fzf-z
    # For GNU ls (the binaries can be gls, gdircolors)
    zplugin ice atclone"dircolors -b LS_COLORS > c.zsh" atpull'%atclone' pick"c.zsh"
    zplugin light trapd00r/LS_COLORS

    # Syntax highlighting
    zplugin ice wait"0" atinit"zpcompinit" lucid
    zplugin light zdharma/fast-syntax-highlighting
}

SetupOhMyZsh
SetupZplugin
SetupFzf
SetupCommonShell

# Initialize completions
autoload -Uz compinit && compinit

#--------------------------------------------
# Stop performance profiler (if enabled)
#--------------------------------------------
if [[ "$ZPROF" = true ]]; then
  zprof
fi

