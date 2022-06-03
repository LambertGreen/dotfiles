'-------------------------------------------------------------------------------
' Script to launch GUI Emacs from WSL
'
' Usage:
' - Call this script from a shortcut link in StartMenu\Programs i.e.
'   (%HOME%\AppData\Roaming\Microsoft\Windows\Start Menu\Programs)
'
' Requirements:
' - WSL setup with X11 forwarding
' - Emacs installed in WSL
'-------------------------------------------------------------------------------

WScript.CreateObject("WScript.Shell").Run "wsl ~ bash -l -c emacs", 0, False
