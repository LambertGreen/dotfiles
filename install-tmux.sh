#!/usr/bin/env bash

TMUX_VERSION="2.0"
LIBEVENT_VERSION="2.0.21-stable"

[ -d ~/packages ] || mkdir ~/packages; pushd ~/packages;
wget https://github.com/downloads/libevent/libevent/libevent-$LIBEVENT_VERSION.tar.gz
tar zxvf libevent-$LIBEVENT_VERSION.tar.gz
cd libevent-$LIBEVENT_VERSION
./configure --prefix=/usr/local
make
sudo make install

[ -d ~/packages ] || mkdir ~/packages; pushd ~/packages;
wget http://downloads.sourceforge.net/tmux/tmux-$TMUX_VERSION.tar.gz
tar zxvf tmux-$TMUX_VERSION.tar.gz
cd tmux-$TMUX_VERSION
#./configure CFLAGS="-I/usr/local/include -I/usr/local/include/ncurses" LDFLAGS="-L/usr/local/lib -L/usr/local/include/ncurses -L/usr/local/include"
LDFLAGS="-L/usr/local/lib -Wl,-rpath=/usr/local/lib" ./configure --prefix=/usr/local
make
sudo make install
