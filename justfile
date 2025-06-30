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

# 🐳 Build Docker test image from LOCAL changes (recommended for development)
docker-build-local:
    @echo "Building Docker image from LOCAL dotfiles changes..."
    @mkdir -p .runtime/logs
    docker build -f Dockerfile.local -t dotfiles-test-local . 2>&1 | tee .runtime/logs/docker-build-local.log

# 🐳 Build Docker test image from LOCAL changes (force rebuild)
docker-build-local-fresh:
    @echo "Building Docker image from LOCAL changes (no cache)..."
    @mkdir -p .runtime/logs
    docker build -f Dockerfile.local --no-cache -t dotfiles-test-local . 2>&1 | tee .runtime/logs/docker-build-local.log

# 🐳 Run LOCAL Docker container for testing
docker-run-local:
    @echo "Running LOCAL Docker container for dotfiles testing..."
    docker run -it dotfiles-test-local

# 🐳 Full LOCAL Docker test cycle (RECOMMENDED FOR DEVELOPMENT)
docker-test-local: docker-build-local docker-run-local

# 🐳 Build Docker test image from REMOTE (requires push first)
docker-build:
    @echo "Building Docker image for dotfiles testing..."
    @mkdir -p .runtime/logs
    source .env && docker build --build-arg GITHUB_TOKEN=${GITHUB_TOKEN} --build-arg CACHE_BUST=$(date +%s) -t dotfiles-test . 2>&1 | tee .runtime/logs/docker-build.log

# 🐳 Build Docker test image (force rebuild all layers)
docker-build-fresh:
    @echo "Building Docker image from scratch..."
    @mkdir -p .runtime/logs
    source .env && docker build --no-cache --build-arg GITHUB_TOKEN=${GITHUB_TOKEN} -t dotfiles-test . 2>&1 | tee .runtime/logs/docker-build.log

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
