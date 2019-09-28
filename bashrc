#!/bin/bash

# If zsh is installed then run it instead
# Note: In general the chsh command can be used to change a user's shell
# but this does not work for domain users.
# See: https://serverfault.com/questions/736471/how-do-i-change-my-default-shell-on-a-domain-account
# To stop the automatic loading of zsh, then define BASH_NO_EXEC_ZSH.
[[ (! -v $BASH_NO_EXEC_ZSH) && -x "$(command -v zsh)" ]] && exec zsh || true

# Source common shell script
[ -f ~/.shell_common ] && source ~/.shell_common
