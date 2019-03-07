#!/bin/sh

# get the directory that this script resides in
scriptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

function InstallVimPlug {
    curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
}

# vim conf
ln -sf $scriptDir/.vimrc ~/.vimrc

# nvim conf
nvim_config=.config/nvim
mkdir ~/$nvim_config
ln -sf $scriptDir/$nvim_config/init.vim ~/$nvim_config/init.vim
ln -sf $scriptDir/$nvim_config/ginit.vim ~/$nvim_config/ginit.vim

# tmux confg
ln -sf $scriptDir/.tmux.conf ~/.tmux.conf

# git config
ln -sf $scriptDir/.gitignore ~/.gitignore

# zsh config
ln -sf $scriptDir/.zshrc ~/.zshrc

