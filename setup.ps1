
# Get directory of this script location
$scriptDir = Split-Path $script:MyInvocation.MyCommand.Path

# Helper functions
function make-link ($target, $link) {
    New-Item -Path $link -ItemType SymbolicLink -Value $target
}

# vim config
mkdir $env:USERPROFILE\.vim\
mkdir $env:USERPROFILE\.vim\backup
mkdir $env:USERPROFILE\.vim\swap
mkdir $env:USERPROFILE\.vim\undo
make-link $scriptDir/.vimrc $env:USERPROFILE/_vimrc

# nvim conf
make-link $scriptDir/.config/nvim/init.vim $env:LOCALAPPDATA/nvim/init.vim  
make-link $scriptDir/.config/nvim/ginit.vim $env:LOCALAPPDATA/nvim/ginit.vim  
