# Readline settings
Set-PSReadlineOption -EditMode Emacs
Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete

# Enable Fzf for fast search for: files, and command history
Import-Module PSFzf -ArgumentList 'Ctrl+T','Ctrl+R'

# Enable fast directory navigation using z command
Import-Module z

# Enable ls colors
Import-Module Get-ChildItemColor
Set-Alias ll Get-ChildItemColor -option AllScope
Set-Alias ls Get-ChildItemColorFormatWide -option AllScope


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

function Set-VsCmd
{
    param(
        [parameter(Mandatory, HelpMessage="Enter VS version as 2010, 2012, 2013, 2015, 2017")]
        [ValidateSet(2010,2012,2013,2015,2017)]
        [int]$version = 2017
    )
    $VS_VERSION = @{ 2010 = "10.0"; 2012 = "11.0"; 2013 = "12.0"; 2015="13.0"; 2017="14.0" }
    $targetDir = "c:\Program Files (x86)\Microsoft Visual Studio $($VS_VERSION[$version])\VC"
    if (!(Test-Path (Join-Path $targetDir "vcvarsall.bat"))) {
        "Error: Visual Studio $version not installed"
        return
    }
    pushd $targetDir
    cmd /c "vcvarsall.bat x64 & set" |
    foreach {
      if ($_ -match "(.*?)=(.*)") {
        Set-Item -force -path "ENV:\$($matches[1])" -value "$($matches[2])"
      }
    }
    popd
    write-host "`nVisual Studio $version Command Prompt variables set." -ForegroundColor Yellow
}

# Bat wrapper because less pager does not correctly show colors,
# so set no paging
function Run-Bat { bat.exe $args --paging=never}
Set-Alias bat Run-Bat -option AllScope

# Gradlew wrapper function
function Run-Gradlew { ./gradlew.bat $args }
Set-Alias gw Run-Gradlew -option AllScope

# Git alias
function Run-Git { git $args }
Set-Alias g Run-Git -option AllScope

# Rather use git aliases so that you can have one
# common config across platforms
# Note: An issue I ran into is that "gc" is an alias for
# Get-Content, and is not a good alias to override, as
# Powershell scripts may use the alias!
#
# function Get-GitStatus { & git status $args }
# function Get-GitAdd { & git add $args }
# function Get-GitDiff { & git diff $args }
# function Get-GitCommit { & git commit $args }
# Set-Alias gs -Value Get-GitStatus
# Set-Alias ga -Value Get-GitAdd
# Set-Alias gd -Value Get-GitDiff
# del alias:gc -Force
# Set-Alias -Name gc -Value Get-GitCommit -Force

# Enable a cool prompt
Import-Module -Name posh-git
Import-Module -Name oh-my-posh

# Set-Theme Honukai
Set-Theme Paradox

# Set code codepage so that unicode is correctly displayed in Vim
chcp 65001 > $null



