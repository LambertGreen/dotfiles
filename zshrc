#!/usr/bin/env zsh
#--------------------------------------------
# Start performance profiler (if enabled)
#--------------------------------------------
if [[ "$ZPROF" = true ]]; then
  zmodload zsh/zprof
fi

lgreen_profile-zsh() {
  shell=${1-$SHELL}
  ZPROF=true $shell -i -c exit
}

lgreen_setup-zsh() {
    # History settings
    export HISTSIZE=1000
    export SAVEHIST=1000
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
}

lgreen_setup-oh-my-zsh () {

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
        fzf
        colored-man-pages
    )

    source $ZSH/oh-my-zsh.sh
}

lgreen_setup-fzf() {
    export FZF_BASE=$HOME/.fzf
}

lgreen_setup-common-shell() {
    # Source common shell script
    [ -f $HOME/.shell_common ] && source $HOME/.shell_common
    # Source local config file if is present
    [ -f $HOME/.zshrc_local ] && source $HOME/.zshrc_local
}

#--------------------------------------------
# Zinit
#--------------------------------------------
# Zinit: https://github.com/zdharma/zinit
# Install: sh -c "$(curl -fsSL https://raw.githubusercontent.com/zdharma/zinit/master/doc/install.sh)"
#--------------------------------------------
lgreen_setup-oh-my-zsh-using-zinit() {
    setopt promptsubst

    # Git
    [[ -v "$ZPLUGIN_ICE" ]] && zinit ice wait"0" lucid
    zinit snippet OMZ::lib/git.zsh

    # More git?
    [[ -v "$ZPLUGIN_ICE" ]] && zinit ice wait"0" atload"unalias grv" lucid
    zinit snippet OMZ::plugins/git/git.plugin.zsh

    # Color man-pages
    [[ -v "$ZPLUGIN_ICE" ]] && zinit ice wait"0" lucid
    zinit snippet OMZ::plugins/colored-man-pages/colored-man-pages.plugin.zsh

    # fzf
    [[ -v "$ZPLUGIN_ICE" ]] && zinit ice wait"0" lucid
    zinit snippet OMZ::plugins/fzf/fzf.plugin.zsh

    # Theme
    # [[ -v "$ZPLUGIN_ICE" ]] && zinit ice wait"0" lucid
    # zinit snippet OMZ::themes/agnoster.zsh-theme
    #
}

lgreen_setup-zinit() {
    source $HOME/.zinit/bin/zinit.zsh

    autoload -Uz _zinit
    (( ${+_comps} )) && _comps[zinit]=_zinit

    # lgreen_setup-oh-my-zsh-using-zinit
    # [[ -v "$ZPLUGIN_ICE" ]] && zinit ice wait"0"
    # zinit light robbyrussell/oh-my-zsh

    [[ -v "$ZPLUGIN_ICE" ]] && zinit ice wait"0" blockf
    zinit light zsh-users/zsh-completions

    [[ -v "$ZPLUGIN_ICE" ]] && zinit ice wait"0" atload"_zsh_autosuggest_start"
    zinit light zsh-users/zsh-autosuggestions

    # Z
    zinit light agkozak/zsh-z

    # Fzf-z
    zinit light andrewferrier/fzf-z

    # For GNU ls (the binaries can be gls, gdircolors)
    zinit ice atclone"gdircolors -b LS_COLORS > c.zsh" atpull'%atclone' pick"c.zsh" nocompile'!'
    zinit light trapd00r/LS_COLORS
    # if [[ `which gdircolors &>/dev/null && $?` != 0 ]]; then
    #     zinit ice atclone"gdircolors -b LS_COLORS > c.zsh" atpull'%atclone' pick"c.zsh" nocompile'!'
    #     zinit light trapd00r/LS_COLORS
    # fi
    # if [[ `which dircolors &>/dev/null && $?` != 0 ]]; then
    #     zinit ice atclone"dircolors -b LS_COLORS > c.zsh" atpull'%atclone' pick"c.zsh" nocompile'!'
    #     zinit light trapd00r/LS_COLORS
    # fi

    # Syntax highlighting
    [[ -v "$ZPLUGIN_ICE" ]] && zinit ice wait"0" atinit"zpcompinit" lucid
    zinit light zdharma/fast-syntax-highlighting

    zinit ice depth=1
    zinit light romkatv/powerlevel10k
}

lgreen_setup-fzf
#lgreen_setup-oh-my-zsh
unset ZPLUGIN_ICE
#export ZPLUGIN_ICE=1
lgreen_setup-zinit
lgreen_setup-common-shell

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Initialize completions
autoload -Uz compinit && compinit

lgreen_zsh_show_functions() {
    print -l ${(k)functions} | fzf
}

#--------------------------------------------
# Stop performance profiler (if enabled)
#--------------------------------------------
if [[ "$ZPROF" = true ]]; then
    unset ZPROF
    zprof
fi

