#!/usr/bin/env zsh

#--------------------------------------------
# Start performance profiler (if enabled)
#--------------------------------------------
if [[ "$ZPROF" = true ]]; then
  zmodload zsh/zprof
fi

lgreen_setup_p10k() {
    # Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
    # Initialization code that may require console input (password prompts, [y/n]
    # confirmations, etc.) must go above this block; everything else may go below.
    if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
        source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
    fi
}

lgreen_init_p10k() {
    # To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
    [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
}

lgreen_profile_zsh() {
  shell=${1-$SHELL}
  ZPROF=true $shell -i -c exit
}

lgreen_setup_zsh() {
    # Set zle to use Emacs keybinds
    bindkey -e

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

lgreen_init_fzf() {
    # Note: FZF exports are done in shell_common
    [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
}

lgreen_setup_common_shell() {
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
lgreen_setup_zinit() {
    if [[ ! -f $HOME/.zinit/bin/zinit.zsh ]]; then
        print -P "%F{33}▓▒░ %F{220}Installing DHARMA Initiative Plugin Manager (zdharma/zinit)…%f"

        # Might be safer to clone the repro than just running some script from the internet?
        # TODO: don't just execute, and rather clone from your own fork.
        #
        #sh -c "$(curl -fsSL https://raw.githubusercontent.com/zdharma/zinit/master/doc/install.sh)"
        print -P "Actually not going to install anything automatically... that is not a secure thing to do."
        print -P "Clone a fork of the repo your self."

        # Alternative:
        # command mkdir -p "$HOME/.zinit" && command chmod g-rwX "$HOME/.zinit"
        # command git clone https://github.com/zdharma/zinit "$HOME/.zinit/bin" && \
        # print -P "%F{33}▓▒░ %F{34}Installation successful.%f" || \
        # print -P "%F{160}▓▒░ The clone has failed.%f"
    fi
    source $HOME/.zinit/bin/zinit.zsh

    autoload -Uz _zinit
    (( ${+_comps} )) && _comps[zinit]=_zinit

    # Ice it up?
    #unset ZPLUGIN_ICE
    export ZPLUGIN_ICE=1

    zinit for \
        OMZ::lib/history.zsh \
        OMZ::lib/functions.zsh \
        OMZ::lib/misc.zsh \
        OMZ::lib/completion.zsh

    # # OMZ::History
    # [[ -v "$ZPLUGIN_ICE" ]] && zinit ice wait"0" lucid
    # zinit snippet OMZ::lib/history.zsh

    # # OMZ::Git
    # [[ -v "$ZPLUGIN_ICE" ]] && zinit ice wait"0" lucid
    # zinit snippet OMZ::lib/git.zsh

    # OMZ::Color man-pages
    [[ -v "$ZPLUGIN_ICE" ]] && zinit ice wait"0" lucid
    zinit snippet OMZ::plugins/colored-man-pages/colored-man-pages.plugin.zsh

    # zsh-completions
    [[ -v "$ZPLUGIN_ICE" ]] && zinit ice wait"0" blockf
    zinit light zsh-users/zsh-completions

    # zsh-autosuggestions
    [[ -v "$ZPLUGIN_ICE" ]] && zinit ice wait"0" atload"_zsh_autosuggest_start"
    zinit light zsh-users/zsh-autosuggestions

    # Syntax highlighting
    [[ -v "$ZPLUGIN_ICE" ]] && zinit ice wait"0" atinit"zpcompinit" lucid
    zinit light zdharma/fast-syntax-highlighting

    # Theme: powerlevel10k
    zinit ice depth=1
    zinit light romkatv/powerlevel10k

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
}

lgreen_zsh_show_functions() {
    print -l ${(k)functions} | fzf
}


# Emacs Tramp: needs a simple prompt so just setup common shell
# and return
if [[ $TERM == "dumb" ]]; then
    lgreen_setup_common_shell
    unsetopt zle && PS1='$ '
    return
fi

lgreen_setup_zinit
lgreen_setup_p10k
lgreen_setup_zsh
lgreen_setup_common_shell
lgreen_init_p10k
lgreen_init_fzf

# Initialize completions
autoload -Uz compinit && compinit
zinit cdreplay -q


#--------------------------------------------
# Stop performance profiler (if enabled)
#--------------------------------------------
if [[ "$ZPROF" = true ]]; then
    unset ZPROF
    zprof
fi
### End of Zinit's installer chunk
