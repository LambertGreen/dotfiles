# Development Setup

This directory contains scripts for checking the development environment.

## Quick Start

For new developers (and AI assistants), run:

```bash
./devsetup/check-prerequisites.sh
```

This will check for direnv and pyenv (the essential tools).

## Prerequisites

The script checks for:

- **direnv**: Environment management
- **pyenv**: Python version management

## Setup

1. Install prerequisites:
   ```bash
   brew install direnv pyenv
   ```

2. Add to your shell profile (~/.zshrc or ~/.bashrc):
   ```bash
   eval "$(direnv hook zsh)"
   eval "$(pyenv init -)"
   ```

3. Activate the environment:
   ```bash
   direnv allow && eval "$(direnv export bash)"
   ```

## For AI Assistants

When working with this project:

1. **Check prerequisites**: `./devsetup/check-prerequisites.sh`
2. **Activate environment**: `direnv allow && eval "$(direnv export bash)"`
3. **Run tests**: Use `just goto-testing` to enter the testing context

This ensures consistent development environments across all contributors.
