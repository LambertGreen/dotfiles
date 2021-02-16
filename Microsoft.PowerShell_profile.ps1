# Readline settings
Set-PSReadlineOption -EditMode Emacs
Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete

# Enable Fzf for fast search for: files, and command history
Import-Module PSFzf
Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'

# Enable fast directory navigation using z command
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

# Git alias
function lgreen-run-git { git $args }
Set-Alias g lgreen-run-git -option AllScope

# Enable a cool prompt
Import-Module -Name posh-git
Import-Module -Name oh-my-posh

Set-Theme Powerlevel10k-Lean

# Set code codepage so that unicode is correctly displayed in Vim
chcp 65001 > $null
