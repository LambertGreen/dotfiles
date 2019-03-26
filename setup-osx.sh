#!/bin/sh

# source common setup file
source ./setup-posix-common.sh

function createOsxConfigSymLinks {
    # karabiner
    createConfigSymLink config/karabiner
}
