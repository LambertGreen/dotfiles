#!/usr/bin/env just
# -*- mode: just -*-

# General dotfiles management commands

default:
    @just --list

# 🧪 Test applications in tmux session
test-apps:
    @echo "Starting automated dotfiles testing..."
    tmux new-session -d -s dotfiles-test \; \
    send-keys 'echo "=== Dotfiles Testing Session ===" && fastfetch' Enter \; \
    new-window -n vim \; send-keys 'vim' \; \
    new-window -n nvim \; send-keys 'nvim' \; \
    new-window -n emacs \; send-keys 'emacs -nw' \; \
    new-window -n htop \; send-keys 'htop' \; \
    new-window -n shell \; send-keys 'echo "Shell test - aliases, functions, etc." && alias' Enter \; \
    select-window -t 0 \; \
    attach-session -t dotfiles-test

# 🐳 Build Docker test image (with layer caching)
docker-build:
    @echo "Building Docker image for dotfiles testing..."
    source .env && docker build --build-arg GITHUB_TOKEN=${GITHUB_TOKEN} --build-arg CACHE_BUST=$(date +%s) -t dotfiles-test . 2>&1 | tee docker-build.log

# 🐳 Build Docker test image (force rebuild all layers)
docker-build-fresh:
    @echo "Building Docker image from scratch..."
    source .env && docker build --no-cache --build-arg GITHUB_TOKEN=${GITHUB_TOKEN} -t dotfiles-test . 2>&1 | tee docker-build.log

# 🐳 Run Docker container for testing
docker-run:
    @echo "Running Docker container for dotfiles testing..."
    docker run -it dotfiles-test

# 🐳 Full Docker test cycle
docker-test: docker-build docker-run

# 📋 Show current git status
status:
    git status

# 🔄 Update submodules
update-submodules:
    git submodule update --init --recursive
