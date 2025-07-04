#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Emacs (new instance)
# @raycast.mode compact

# Optional parameters:
# @raycast.icon /opt/homebrew/opt/emacs-mac-exp/Emacs.app/Contents/Resources/Emacs.icns
# @raycast.packageName Emacs Launcher

# Documentation:
# @raycast.description Launches a new instance of Emacs GUI with custom init dir
# @raycast.author Lambert Green

open -n -a Emacs --args --init-directory ~/.emacs.default
