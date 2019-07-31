#!/bin/sh

# source common setup file
source ./setup-posix-common.sh

createOsxConfigSymLinks() {

    createConfigSymLink profile_osx

    # karabiner
    createConfigSymLink config/karabiner
}

