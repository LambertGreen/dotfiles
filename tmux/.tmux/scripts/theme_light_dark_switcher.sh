#!/usr/bin/env bash

lgreen_source_tmux_theme_light() {
    TMUX_THEME_FILE="$(tmux showenv -g TMUX_THEME_LIGHT | sed 's/TMUX_THEME_LIGHT=//g')"
    if [ -f $TMUX_THEME_FILE ]; then
        tmux source "$TMUX_THEME_FILE"
        tmux setenv -g TMUX_THEME_FILE "$TMUX_THEME_FILE"
        tmux setenv -g TMUX_THEME "light"
    fi
}

lgreen_source_tmux_theme_dark() {
    TMUX_THEME_FILE="$(tmux showenv -g TMUX_THEME_DARK | sed 's/TMUX_THEME_DARK=//g')"
    if [ -f $TMUX_THEME_FILE ]; then
        tmux source "$TMUX_THEME_FILE"
        tmux setenv -g TMUX_THEME_FILE "$TMUX_THEME_FILE"
        tmux setenv -g TMUX_THEME "dark"
    fi
}

lgreen_toggle_tmux_light_dark_mode() {
    if [ "$(tmux showenv -g TMUX_THEME)" = "TMUX_THEME=light" ]; then
        lgreen_source_tmux_theme_dark
    else
        lgreen_source_tmux_theme_light
    fi
}

lgreen_source_startup_theme() {
    if [ ! "$(tmux showenv -g TMUX_THEME_FILE 2>/dev/null)" ]; then
        lgreen_source_tmux_theme_dark
    fi
}

alias tt=lgreen_toggle_tmux_light_dark_mode

lgreen_source_startup_theme
