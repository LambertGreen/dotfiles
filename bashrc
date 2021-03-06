#!/usr/bin/env bash

# Don't exec ZSH if this is a dumb shell e.g. Emacs Tramp
if [[ $TERM == "dumb" ]]; then
    export BASH_NO_EXEC_ZSH=1
fi

# If zsh is installed then run it instead
# Note: In general the chsh command can be used to change a user's shell
# but this does not work for domain users.
# See: https://serverfault.com/questions/736471/how-do-i-change-my-default-shell-on-a-domain-account
# To stop the automatic loading of zsh, then define BASH_NO_EXEC_ZSH.
if [ -z "$BASH_NO_EXEC_ZSH" ] && [ "$(command -v zsh)" ]; then
    exec zsh
else
    # Source common shell script
    # shellcheck source=shell_common
    [ -f ~/.shell_common ] && source ~/.shell_common
    [ -f ~/.fzf.bash ] && source ~/.fzf.bash

    lgreen_setup_direnv_for_bash
fi

