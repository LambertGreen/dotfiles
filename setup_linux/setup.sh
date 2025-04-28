#!/usr/bin/env sh

lgreen_setup_install_nerd_font() {
    echo "-- Installing nerd font --"
    echo "Downloading font..."
    mkdir -p ~/.local/share/fonts
    pushd ~/.local/share/fonts || exit
    curl -fLo "Iosevka Nerd Font Completet.tff" \
        https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/Iosevka/IosevkaNerdFont-Regular.ttf
    echo "Update font cache..."
    fc-cache -fv
    popd || exit
    echo "Done."
}
