#!/bin/bash
# Herdr theme toggle script
# Toggles between catppuccin (dark) and catppuccin-latte (light)

CONFIG_FILE="$HOME/.config/herdr/config.toml"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Herdr config not found at $CONFIG_FILE"
    exit 1
fi

# Read current theme
current_theme=$(grep '^name = ' "$CONFIG_FILE" | head -1 | sed 's/.*"\(.*\)".*/\1/')

# Toggle theme
if [[ "$current_theme" == "catppuccin" ]]; then
    new_theme="catppuccin-latte"
    new_mode="light"
else
    new_theme="catppuccin"
    new_mode="dark"
fi

# Update config
sed -i.bak "s/^name = \".*\"/name = \"$new_theme\"/" "$CONFIG_FILE"

# Reload Herdr config
if command -v herdr >/dev/null 2>&1; then
    herdr server reload-config >/dev/null 2>&1
fi

echo "Switched to $new_theme ($new_mode mode)"
