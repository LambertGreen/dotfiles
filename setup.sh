#!/bin/sh

# get the directory that this script resides in
scriptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

# vim conf
ln -s $scriptDir/.vimrc ~/.vimrc  

# nvim conf
nvim_config=.config/nvim
mkdir ~/$nvim_config
ln -s $scriptDir/$nvim_config/init.vim ~/$nvim_config/init.vim

# tmux confg
ln -s $scriptDir/.tmux.conf ~/.tmux.conf

# git config
ln -s $scriptDir/.gitignore ~/.gitignore

# zsh config
ln -s $scriptDir/.zshrc ~/.zshrc
