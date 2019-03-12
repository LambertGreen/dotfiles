# Readline settings
Set-PSReadlineOption -EditMode Emacs
Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete

# Enable Fzf for fast search for: files, and command history
Import-Module PSFzf -ArgumentList 'Ctrl+T','Ctrl+R'

# Enable ls colors
Import-Module Get-ChildItemColor
Set-Alias ll Get-ChildItemColor -option AllScope
Set-Alias ls Get-ChildItemColorFormatWide -option AllScope

# Enable a cool prompt
Import-Module -Name posh-git
Import-Module -Name oh-my-posh

# Set-Theme Honukai
Set-Theme Paradox

# Chocolatey profile
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
  Import-Module "$ChocolateyProfile"
}
