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

function lgreen-set-visual-studio-env
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
function lgreen-run-bat { bat.exe $args --paging=never}
Set-Alias bat lgreen-run-bat -option AllScope

# Show files when running tree command
function lgreen-run-tree { tree.com /F }
Set-Alias tree lgreen-run-tree

Set-Alias which get-command
Set-Alias g git

# Enable a cool prompt
Import-Module -Name posh-git
Import-Module -Name oh-my-posh

# Set-Theme Honukai
Set-Theme Paradox

# Set code codepage so that unicode is correctly displayed in Vim
chcp 65001 > $null
