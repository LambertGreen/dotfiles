#!/bin/sh

# get the directory that this script resides in
scriptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

# vim conf
ln -sbf $scriptDir/.vimrc ~/.vimrc

# nvim conf
nvim_config=.config/nvim
mkdir ~/$nvim_config
ln -sbf $scriptDir/$nvim_config/init.vim ~/$nvim_config/init.vim

# tmux confg
ln -sbf $scriptDir/.tmux.conf ~/.tmux.conf

# git config
ln -sbf $scriptDir/.gitignore ~/.gitignore

# zsh config
ln -sbf $scriptDir/.zshrc ~/.zshrc
