#!/usr/bin/env bash
set -euo pipefail

# Needed to add this file because Homebrew stopped working on CentOS7
#

ZSH_SRC_NAME=$HOME/packages/zsh.tar.xz
ZSH_PACK_DIR=$HOME/packages/zsh
ZSH_LINK="https://sourceforge.net/projects/zsh/files/latest/download"

if [ ! -d "$ZSH_PACK_DIR" ]; then
    echo "Creating zsh directory under packages directory"
    mkdir -p "$ZSH_PACK_DIR"
fi

if [ ! -f "$ZSH_SRC_NAME" ]; then
    curl -Lo "$ZSH_SRC_NAME" "$ZSH_LINK"
fi

tar xJvf "$ZSH_SRC_NAME" -C "$ZSH_PACK_DIR" --strip-components 1
cd "$ZSH_PACK_DIR"

./configure --prefix="$HOME/local" \
    CPPFLAGS="-I$HOME/local/include" \
    LDFLAGS="-L$HOME/local/lib"
make -j && make install
