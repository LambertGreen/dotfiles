
# Get directory of this script location
$scriptDir = Split-Path $script:MyInvocation.MyCommand.Path

# Helper functions
function make-link ($target, $link) {
    New-Item -Path $link -ItemType SymbolicLink -Value $target -Force
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
    make-link $scriptDir/vimrc $env:USERPROFILE/_vimrc
    InstallVimPlug

# gvim config
    make-link $scriptDir/gvimrc $env:USERPROFILE/_gvimrc
}

function SymlinkNeovim() {
# nvim conf

    mkdir $env:LOCALAPPDATA/nvim
    make-link $scriptDir/config/nvim/init.vim $env:LOCALAPPDATA/nvim/init.vim
    make-link $scriptDir/config/nvim/ginit.vim $env:LOCALAPPDATA/nvim/ginit.vim
}

function SymlinkOni() {
    make-link $scriptDir/config/oni/config.tsx $env:APPDATA/oni/config.tsx
}

function SymlinkFlake8() {
    make-link $scriptDir/config/flake8 $env:HOMEPATH/.flake8
}

function SymlinkSpacemacs() {
    make-link $scriptDir/spacemacs.el $env:HOMEPATH/.spacemacs
}

function SymlinkKeypirinha() {
    make-link $scriptDir/Keypirinha/Keypirinha.ini $env:HOMEPATH/scoop/persist/keypirinha/portable/Profile/User/Keypirinha.ini
}

function SymlinkConEmu() {
    make-link $scriptDir/ConEmu/ConEmu.xml $env:HOMEPATH/scoop/apps/conemu/current/ConEmu/ConEmu.xml
}
