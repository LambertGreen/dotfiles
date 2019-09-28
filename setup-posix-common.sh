#!/bin/sh

# get the directory that this script resides in
scriptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

function InstallVimPlug {
    curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    }

function removeConfigSymLink {
    echo "Removing symlink '$1'..."
    test -h $1 || (echo "Error: '$1' not a symlink!"; return 1);
    rm $1
}

function createSymLink {
    echo "Symlinking '$1' to '$2'..."
    ln -sf $1 $2
}

function createConfigSymLink {
    local target=$scriptDir/$1
    local link=$HOME/.$1
    createSymLink $link $target
}

function createConfigSymLinks {
    # Common profile and shell
    createConfigSymLink profile
    createConfigSymLink shell_common

    # bash
    createConfigSymLink bash_profile
    createConfigSymLink bashrc

    # zsh
    createConfigSymLink zprofile
    createConfigSymLink zshrc

    # tmux
    createConfigSymLink tmux.conf

    # git
    createConfigSymLink gitignore

    # vim
    createConfigSymLink vimrc
    createConfigSymLink gvimrc

    # nvim
    if test -d ~/.config/nvim; then
        createConfigSymLink config/nvim/init.vim
        createConfigSymLink config/nvim/ginit.vim
    else
        (echo "Nvim directory '.config/nvim' does not exist! Install Nvim first.")
    fi

    # oni
    if test -d ~/.config/oni; then
        createConfigSymLink config/oni/config.tsx
    else
        (echo "Nvim directory '.config/nvim' does not exist! Install Nvim first.")
    fi

    # flake8
    createConfigSymLink config/flake8

    # Spacemacs
    createSymLink $scriptDir/spacemacs.el $HOME/.spacemacs
}


