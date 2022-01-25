#!/usr/bin/env bash

lgreen_source_tmux_theme_light() {
    export TMUX_THEME_FILE="$(tmux showenv -g TMUX_THEME_LIGHT | sed 's/TMUX_THEME_LIGHT=//g')"
    tmux source "$TMUX_THEME_FILE"
    tmux setenv -g TMUX_THEME "light"
}

lgreen_source_tmux_theme_dark() {
    export TMUX_THEME_FILE="$(tmux showenv -g TMUX_THEME_DARK | sed 's/TMUX_THEME_DARK=//g')"
    tmux source "$TMUX_THEME_FILE"
    tmux setenv -g TMUX_THEME "dark"
}

lgreen_toggle_tmux_light_dark_mode() {
    if [ "$(tmux showenv -g TMUX_THEME)" = "TMUX_THEME=light" ]; then
        lgreen_source_tmux_theme_dark
    else
        lgreen_source_tmux_theme_light
    fi
}

alias tt=lgreen_toggle_tmux_light_dark_mode

lgreen_source_tmux_theme_dark
