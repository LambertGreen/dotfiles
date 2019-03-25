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

# Set ConEmu to display CWD in Window title
# Note: This function is just an example of
# the metod to update the prompt.  The prompt
# is actually updated by the global:Prompt
# function.  To make it effective for a particular
# theme one needs to update the theme file directly
# Example: WindowsPowerShell\Modules\oh-my-posh\2.0.225\Themes\Paradox.psm1
function updateConEmuWindowTitleToShowCwd
{
  $prompt = & $GitPromptScriptBlock
  if ($env:ConEmuANSI -eq "ON")
  {
    $prompt += "$([char]27)]2;`"$((Get-Location).Path)`"$([char]7)"
  }
  $prompt
}

# Bat wrapper because less pager does not correctly show colors,
# so set no paging
function bat { bat.exe $args --paging=never}

# Gradlew wrapper function
function gw { ./gradlew.bat $args }

# Set code codepage so that unicode is correctly displayed in Vim
chcp 65001 > $null
