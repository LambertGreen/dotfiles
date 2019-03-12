
# Get directory of this script location
$scriptDir = Split-Path $script:MyInvocation.MyCommand.Path

# Helper functions
function make-link ($target, $link) {
    New-Item -Path $link -ItemType SymbolicLink -Value $target
}

function InstallVimPlug() {
    mkdir ~\.vim\autoload
    $uri = 'https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
    (New-Object Net.WebClient).DownloadFile(
      $uri,
      $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(
        "~\.vim\autoload\plug.vim"
      )
    )
}

function SymlinkPowershell() {
# Powershell config
    make-link $scriptDir/Microsoft.PowerShell_profile.ps1 $env:USERPROFILE/Documents/WindowsPowerShell/Microsoft.PowerShell_profile.ps1
}

function SymlinkVim() {
# vim config
    mkdir $env:USERPROFILE\.vim\
    mkdir $env:USERPROFILE\.vim\backup
    mkdir $env:USERPROFILE\.vim\swap
    mkdir $env:USERPROFILE\.vim\undo
    make-link $scriptDir/.vimrc $env:USERPROFILE/_vimrc
    InstallVimPlug

# gvim config
    make-link $scriptDir/.gvimrc $env:USERPROFILE/_gvimrc
}

function SymlinkNeovim() {
# nvim conf
    make-link $scriptDir/.config/nvim/init.vim $env:LOCALAPPDATA/nvim/init.vim
    make-link $scriptDir/.config/nvim/ginit.vim $env:LOCALAPPDATA/nvim/ginit.vim
}
