#!/bin/bash

# ubuntu-post-install.sh
# Ubuntu system configuration for my dotfiles

set -e  # Exit on error

echo "Configuring GNOME keybindings..."

# Disable Super+v (notification center) to allow Emacs binding
gsettings set org.gnome.shell.keybindings toggle-message-tray "[]"

# Add any other GNOME/Ubuntu-specific settings here
# gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
# etc.

echo "GNOME configuration complete!"
