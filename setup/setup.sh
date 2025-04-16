#!/usr/bin/env sh

lgreen_update_github_remote_url_for_personal_user_account() {
    # Prerequisite: update `~/.ssh/config` to include section:
    # Host github.com-personal
    if [ "$(uname)" = "Darwin" ]; then
        SED="gsed"
    else
        SED="sed"
    fi
    remote_url=$(git remote get-url origin)
    new_url=$(echo $remote_url | $SED "s/git@github.com\([^:]*\):/git@github.com-personal:/")
    git remote set-url origin $new_url
}

lgreen_update_github_remote_url_for_work_user_account() {
    # Prerequisite: update `~/.ssh/config` to include section:
    # Host github.com-work
    if [ "$(uname)" = "Darwin" ]; then
        SED=gsed
    else
        SED=sed
    fi
    remote_url=$(git remote get-url origin)
    new_url=$(echo $remote_url | $SED "s/git@github.com\([^:]*\):/git@github.com-work:/")
    git remote set-url origin $new_url
}

lgreen_update_github_submodules_remote_url_for_personal_user_account() {
    git submodule foreach 'source ~/dev/my/dotfiles/setup/setup.sh; lgreen_update_github_remote_url_for_personal_user_account'
}

lgreen_setup_wezterm_shell_completions() {
    wezterm shell-completion --shell zsh >~/.config/zsh/completions/_wezterm
    wezterm shell-completion --shell bash >~/.config/bash/completions/_wezterm
}
