#!/usr/bin/env bash

TMUX_VERSION="2.0"
LIBEVENT_VERSION="2.0.21-stable"

# ----------------
# Install libevent
# ----------------
[ -d ~/packages ] || mkdir ~/packages; pushd ~/packages;
wget https://github.com/downloads/libevent/libevent/libevent-$LIBEVENT_VERSION.tar.gz
tar zxvf libevent-$LIBEVENT_VERSION.tar.gz
cd libevent-$LIBEVENT_VERSION
./configure --prefix=/usr/local
make
sudo make install

# ----------------
# Install Tmux
# ----------------
[ -d ~/packages ] || mkdir ~/packages; pushd ~/packages;
wget http://downloads.sourceforge.net/tmux/tmux-$TMUX_VERSION.tar.gz
tar zxvf tmux-$TMUX_VERSION.tar.gz
cd tmux-$TMUX_VERSION
LDFLAGS="-L/usr/local/lib -Wl,-rpath=/usr/local/lib" ./configure --prefix=/usr/local
make
sudo make install
