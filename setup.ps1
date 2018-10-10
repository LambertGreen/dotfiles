
# Get directory of this script location
$scriptDir = Split-Path $script:MyInvocation.MyCommand.Path

# Helper functions
function make-link ($target, $link) {
    New-Item -Path $link -ItemType SymbolicLink -Value $target
}

# nvim conf
make-link $scriptDir/.config/nvim/init.vim $env:LOCALAPPDATA/nvim/init.vim  
