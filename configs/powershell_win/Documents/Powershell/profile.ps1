# Readline settings
Set-PSReadlineOption -EditMode Emacs
Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete

# Enable Fzf for fast search for: files, and command history
Import-Module PSFzf
Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'

# Enable git completions
Import-Module posh-git

# Enable fast directory navigation using z command
# TODO: Consider using Zoxide
Import-Module z

# Enable ls colors
Import-Module Get-ChildItemColor
Set-Alias ll Get-ChildItemColor -option AllScope
Set-Alias ls Get-ChildItemColorFormatWide -option AllScope

# Bat wrapper because less pager does not correctly show colors,
# so set no paging
function lgreen-run-bat { bat.exe $args --paging=never}
Set-Alias bat lgreen-run-bat -option AllScope

# Show files when running tree command
function lgreen-run-tree { tree.com /F }
Set-Alias tree lgreen-run-tree

Set-Alias which get-command
Set-Alias g git
Set-Alias gw ./gradlew

# Enable a cool prompt
# Using Oh-My-Posh v3: installed via scoop
& ([ScriptBlock]::Create((oh-my-posh init pwsh --config "~/dev/pub/oh-my-posh/themes/amro.omp.json" --print) -join "`n"))

# Set code codepage so that unicode is correctly displayed in Vim
chcp 65001 > $null

# Chocolatey profile
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
  Import-Module "$ChocolateyProfile"
}

# Enable Windows dark mode
function lgreen-enable-dark-mode {
  Set-ItemProperty `
    -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize `
    -Name AppsUseLightTheme `
    -Value 0
}

# Disable Windows dark mode
function lgreen-enable-light-mode {
  Set-ItemProperty `
    -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize `
    -Name AppsUseLightTheme `
    -Value 1
}
Set-Alias okta-aws C:\okta-aws.bat
