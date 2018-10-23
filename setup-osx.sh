#!/bin/sh

# get the directory that this script resides in
scriptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

# karabiner conf
ln -s $scriptDir/.config/karabiner ~/.config

# Hammerspoon script
ln -s $scriptDir/.hammerspoon/init.lua ~/.hammerspoon/init.lua
