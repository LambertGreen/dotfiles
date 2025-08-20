# Dotfiles Management System
# Note: Configuration loaded from ~/.dotfiles.env via shell sourcing in commands

# Environment variables (will be loaded from ~/.dotfiles.env in commands)
platform := env_var_or_default("DOTFILES_PLATFORM", "")

# Set DOTFILES_DIR for all commands
export DOTFILES_DIR := justfile_directory()

# Show available commands
[private]
default:
    @echo "🏠 Dotfiles Management System"
    @echo ""
    @./scripts/show-config.sh
    @echo "🚀 Fresh Setup (New Machine):"
    @echo "  just configure         - Interactive configuration (select machine class)"
    @echo "  just bootstrap         - Bootstrap system (install core tools like Python, Just)"
    @echo "  just stow              - Deploy configuration files (dotfiles symlinks)"
    @echo "  just install-packages  - Install all packages for this machine"
    @echo "  just install-packages-sudo - Install packages requiring sudo (Docker Desktop, etc.)"
    @echo ""
    @echo "🔄 Maintenance (Regular Updates):"
    @echo "  just check-packages      - Check system packages (brew, apt, pip, npm)"
    @echo "  just upgrade-packages    - Upgrade system packages"
    @echo "  just check-dev-packages  - Check dev packages (zsh, emacs, neovim, cargo, pipx)"
    @echo "  just upgrade-dev-packages - Upgrade dev packages"
    @echo "  just init-dev-packages    - Initialize dev packages (first-time setup)"
    @echo "  just verify-dev-package-install - Verify dev package installation"
    @echo "  just check-all-packages   - Check both system and dev packages"
    @echo "  just upgrade-all-packages - Upgrade both system and dev packages"
    @echo "  just export-packages     - Update machine class with currently installed packages"
    @echo ""
    @echo "🏥 Health Check & Troubleshooting:"
    @echo "  just check-health      - Validate system health (auto-logs)"
    @echo "  just check-health-verbose - Detailed health check output"
    @echo "  just cleanup-broken-links-dry-run - List broken symlinks"
    @echo "  just cleanup-broken-links-remove  - Remove broken symlinks"
    @echo ""
    @echo "📊 Show Information:"
    @echo "  just show-package-list  - Show full list of packages (pipeable to pager)"
    @echo "  just show-package-stats - Show package counts summary"
    @echo "  just show-config       - Show dotfiles and machine class configuration"
    @echo "  just show-logs         - Show recent package management logs"
    @echo ""
    @echo "🛠️  Project Development & Testing:"
    @echo "  just testing           - Enter testing sub-shell (Docker test commands)"
    @echo "  just test-arch         - Quick test Arch configuration"
    @echo "  just test-ubuntu       - Quick test Ubuntu configuration"
    @echo ""
    @echo "📁 Logs: logs/ directory - cleanup with: trash logs"

# ═══════════════════════════════════════════════════════════════════════════════
# Package Management - Primary Interface
# Native package manager formats (Brewfile, requirements.txt, etc.)
# ═══════════════════════════════════════════════════════════════════════════════


# Show full list of packages configured for current machine class
show-package-list:
    @./scripts/package-management/show-packages.sh

# Show package counts summary  
show-package-stats:
    @./scripts/package-management/show-package-stats.sh

# Install all packages (non-sudo)
install-packages:
    @./scripts/package-management/import.sh --install --interactive
    @echo ""
    @echo "📝 View log: just show-logs-last"

# Install packages requiring sudo (Docker Desktop, etc.)
install-packages-sudo:
    #!/usr/bin/env bash
    set -euo pipefail
    machine_class_file="${HOME}/.dotfiles.env"
    if [[ ! -f "${machine_class_file}" ]]; then
        echo "Machine class not configured. Run: just configure"
        exit 1
    fi
    source "${machine_class_file}"
    brewfile_sudo="machine-classes/${DOTFILES_MACHINE_CLASS}/brew/Brewfile.casks-sudo"
    if [[ -f "${brewfile_sudo}" ]]; then
        echo "Installing sudo-required casks (you will be prompted for password)..."
        echo "$ brew bundle install --file=\"${brewfile_sudo}\""
        brew bundle install --file="${brewfile_sudo}"
    else
        echo "No sudo-required Brewfile found at: ${brewfile_sudo}"
    fi

# Check for available package updates (system packages)
check-packages:
    @./scripts/package-management/check-packages.sh

# Upgrade all packages (system packages)
upgrade-packages:
    @./scripts/package-management/upgrade-packages.sh

# Check for available dev package updates (zsh, emacs, neovim, cargo, pipx)
check-dev-packages:
    @./scripts/package-management/check-dev-packages.sh

# Upgrade dev packages (zsh, emacs, neovim, cargo, pipx)
upgrade-dev-packages:
    @./scripts/package-management/upgrade-dev-packages.sh

# Initialize dev packages (first-time setup)
init-dev-packages:
    @./scripts/package-management/init-dev-packages.sh

# Verify dev package installation completed successfully
verify-dev-package-install:
    @./scripts/package-management/verify-dev-package-install.sh

# Check all packages (system + dev)
check-all-packages:
    @echo "🔍 Checking system packages..."
    @./scripts/package-management/check-packages.sh
    @echo ""
    @echo "🔍 Checking dev packages..."
    @./scripts/package-management/check-dev-packages.sh

# Upgrade all packages (system + dev)
upgrade-all-packages:
    @echo "🔄 Upgrading system packages..."
    @./scripts/package-management/upgrade-packages.sh
    @echo ""
    @echo "🔄 Upgrading dev packages..."
    @./scripts/package-management/upgrade-dev-packages.sh

# Export current system packages and update machine class
export-packages:
    @./scripts/package-management/export-and-update-machine.sh --update-current

# Show recent package management logs
show-logs:
    @echo "Recent package management logs:"
    @ls -lt logs/package-*.log 2>/dev/null | head -10 || echo "No package logs found"

# Show most recent package management log
show-logs-last:
    @if ls logs/package-*.log >/dev/null 2>&1; then \
        tail -100 `ls -t logs/package-*.log | head -1`; \
    else \
        echo "No package logs found"; \
    fi



# Opens a sub-shell with testing and validation tools
testing:
    @echo "🧪 Opening testing tools..."
    @echo "Type 'just' to see available commands, 'exit' to return to main shell"
    @echo ""
    @cd test && exec $SHELL

# Test specific platform
test-platform platform:
    @cd test && just test-update basic {{platform}}

# Quick test shortcuts
test-arch: (test-platform "arch")
test-ubuntu: (test-platform "ubuntu")


# Validate system health (auto-logs)
check-health:
    @just _check-health-with-log "logs/health-check-$(date +%Y%m%d-%H%M%S).log" ""

# Health check with verbose output
check-health-verbose:
    @just _check-health-with-log "logs/health-check-verbose-$(date +%Y%m%d-%H%M%S).log" "--verbose"

# Internal helper for health checks with logging
[private]
_check-health-with-log logfile flags:
    @mkdir -p "$(dirname {{logfile}})"
    @echo "🏥 Running health check with logging to: {{logfile}}"
    @export DOTFILES_DIR="{{justfile_directory()}}" && bash -c "set -a && source $HOME/.dotfiles.env && set +a && source scripts/health/dotfiles-health.sh && dotfiles_check_health {{flags}} --log {{logfile}}"

# Show current configuration
show-config:
    @if [ ! -f "$HOME/.dotfiles.env" ]; then \
        echo "❌ Configuration file missing. Run: just configure"; \
        exit 1; \
    fi
    @source "$HOME/.dotfiles.env" && echo "📊 Current Configuration:" && echo "  Platform: $DOTFILES_PLATFORM" && echo "  Machine class: $DOTFILES_MACHINE_CLASS"
    @echo "  Machine class configuration:"
    @if [[ -f ~/.dotfiles.env ]]; then \
        source ~/.dotfiles.env; \
        echo "    Location: machine-classes/${DOTFILES_MACHINE_CLASS}/"; \
        echo "    Package managers: ${DOTFILES_PACKAGE_MANAGERS:-not set}"; \
    fi

# List broken symlinks (dry run)
cleanup-broken-links-dry-run:
    @echo "🔍 Finding broken symlinks in dotfiles..."
    @bash -c "export DOTFILES_DIR={{justfile_directory()}} && source scripts/health/dotfiles-health.sh && dotfiles_cleanup_broken_links" 2>&1 || true

# Remove broken symlinks
cleanup-broken-links-remove:
    @bash -c "source scripts/health/dotfiles-health.sh && dotfiles_cleanup_broken_links --remove"

# Interactive configuration (select machine class)
configure:
    @./configure.sh


# Bootstrap system (install core tools)
bootstrap:
    @./bootstrap.sh

# Deploy configuration files
stow:
    @if [ ! -f "$HOME/.dotfiles.env" ]; then \
        echo "❌ Platform not configured. Run: just configure"; \
        exit 1; \
    fi
    @bash -c 'source "$HOME/.dotfiles.env" && ./scripts/stow/stow.sh "$DOTFILES_PLATFORM"'



# Help aliases
[private]
help: default

[private]
h: default

[private]
usage: default