
# get the directory that this script resides in
scriptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

# tmux confg
ln -sf $scriptDir/.tmux-linux.conf ~/.tmux-linux.conf
