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

lgreen_setup_install_minimap_font() {
    echo "-- Installing Minimap font --"
    echo "Downloading font..."
    mkdir -p ~/.local/share/fonts
    pushd ~/.local/share/fonts || exit
    echo "Downloading font..."
    curl -fLo "Minimap.ttf" \
        https://github.com/davestewart/minimap-font/raw/master/src/Minimap.ttf

    echo "Updating font cache..."
    fc-cache -fv
    popd || exit
    echo "Done."
}
