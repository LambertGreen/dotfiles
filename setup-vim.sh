#!/bin/sh

dotfiles=~/dev/my/dotfiles
ln -s $dotfiles/.vimrc ~/.vimrc  

nvim_config=.config/nvim
mkdir ~/$nvim_config
ln -s $dotfiles/$nvim_config/init.vm ~/$nvim_config/init.vm
