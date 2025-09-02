#!/bin/sh
# Helper script to show configuration for justfile

if [ -f "$HOME/.dotfiles.env" ]; then
    . "$HOME/.dotfiles.env"
    echo "📊 Current Configuration:"
    echo "  Platform: $DOTFILES_PLATFORM"
    echo "  Machine class: $DOTFILES_MACHINE_CLASS"
    echo ""
else
    echo "⚠️  Not configured yet. Start with Fresh Setup below."
    echo ""
fi