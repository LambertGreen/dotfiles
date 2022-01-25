#!/usr/bin/env bash

lgreen_setup_tmux_theme_light() {
    if [ -f "$TMUX_LIGHT_THEME" ]; then
        tmux source "$TMUX_LIGHT_THEME"
        export TMUX_THEME="light"
    fi
}

lgreen_setup_tmux_theme_dark() {
    if [ -f "$TMUX_DARK_THEME" ]; then
        tmux source "$TMUX_DARK_THEME"
        export TMUX_THEME="dark"
    fi
}

lgreen_toggle_tmux_light_dark_mode() {
    if [ "$TMUX_THEME" = "light" ]; then
        lgreen_setup_tmux_theme_dark
    else
        lgreen_setup_tmux_theme_light
    fi
}

alias tt=lgreen_toggle_tmux_light_dark_mode
