#############################################################
# Common shell setup file to be sourced from both bash or zsh
#############################################################

# Set PATH
###########
# Set local bins ahead of system PATH
export PATH=$HOME/bin:/usr/local/bin:/usr/local/sbin:$PATH
# Add Ruby
export PATH="$PATH:$HOME/.rvm/bin"
# Add Rust's Cargo
export PATH="$PATH:$HOME/.cargo/bin"

# Set EDITOR
############
VISUAL=nvim
if !type $VISUAL 2> /dev/null; then
    VISUAL=vim
fi
export VISUAL
export EDITOR=$VISUAL

# Set Perforce config to dot file
#################################
export P4CONFIG=.p4config

if [ $(uname -s) == Linux ]; then
    eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv)
elif [ $(uname -s) == Darwin ]; then
    # TODO: Insert Darwin version here
fi

