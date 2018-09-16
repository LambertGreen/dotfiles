#!/bin/sh

# vim conf
dotfiles=~/dev/my/dotfiles
ln -s $dotfiles/.vimrc ~/.vimrc  

# nvim conf
nvim_config=.config/nvim
mkdir ~/$nvim_config
ln -s $dotfiles/$nvim_config/init.vm ~/$nvim_config/init.vm

# tmux confg
ln -s $dotfiles/.tmux.conf ~/.tmux.conf

# git config
ln -s $dotfiles/.gitignore ~/.gitignore
