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
    @echo "  just configure                      - Interactive configuration (select machine class)"
    @echo "  just bootstrap                      - Bootstrap system (install core tools like Python, Just)"
    @echo "  just stow                          - Deploy configuration files (dotfiles symlinks)"
    @echo "  just install-packages              - Install all packages (system → dev → app)"
    @echo ""
    @echo "📦 System Packages (brew, apt, pacman):"
    @echo "  just install-system-packages       - Install system packages (admin → user)"
    @echo "  just check-system-packages         - Check system packages for updates"
    @echo "  just upgrade-system-packages       - Upgrade system packages"
    @echo "  just install-system-packages-admin - Install admin packages (may prompt for password)"
    @echo "  just install-system-packages-user  - Install user packages (no admin required)"
    @echo ""
    @echo "🔧 Development Packages (npm, pip, cargo, gem):"
    @echo "  just install-dev-packages          - Install development language packages"
    @echo "  just check-dev-packages            - Check dev packages for updates"
    @echo "  just upgrade-dev-packages          - Upgrade development packages"
    @echo "  just init-dev-packages             - Initialize dev packages (first-time setup)"
    @echo "  just verify-dev-package-install    - Verify dev package installation"
    @echo ""
    @echo "📱 Application Packages (zinit, elpaca, lazy.nvim):"
    @echo "  just install-app-packages          - Install application package managers"
    @echo "  just check-app-packages            - Check app packages for updates"
    @echo "  just upgrade-app-packages          - Upgrade application packages"
    @echo ""
    @echo "🔄 Unified Package Operations:"
    @echo "  just check-packages                - Check all packages for updates"
    @echo "  just upgrade-packages              - Upgrade all packages"
    @echo "  just export-packages               - Update machine class with installed packages"
    @echo ""
    @echo "🏥 Health Check & Troubleshooting:"
    @echo "  just check-health                     - Validate system health (auto-logs)"
    @echo "  just check-health-verbose             - Detailed health check output"
    @echo "  just cleanup-broken-links-dry-run     - List broken symlinks"
    @echo "  just cleanup-broken-links-remove      - Remove broken symlinks"
    @echo "  just kill-brew-processes              - Kill stuck brew processes (use with caution)"
    @echo ""
    @echo "📊 Show Information:"
    @echo "  just show-package-list                - Show full list of packages (pipeable to pager)"
    @echo "  just show-package-stats               - Show package counts summary"
    @echo "  just show-config                      - Show dotfiles and machine class configuration"
    @echo "  just show-logs                        - Show recent package management logs"
    @echo ""
    @echo "🛠️  Project Development & Testing:"
    @echo "  just testing           - Enter testing sub-shell (Docker test commands)"
    @echo "  just test-arch         - Quick test Arch configuration"
    @echo "  just test-ubuntu       - Quick test Ubuntu configuration"
    @echo ""
    @echo "📁 Logs: .logs/ directory - cleanup with: trash logs"

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

# Install all packages (system, dev, and app packages)
install-packages:
    @echo "📦 Installing all packages for current machine class..."
    @just install-system-packages
    @echo ""
    @just install-dev-packages
    @echo ""
    @just install-app-packages
    @echo ""
    @echo "✅ Package installation complete"

# Install system packages (both admin and user levels)
install-system-packages:
    @echo "🖥️ Installing system packages..."
    @./scripts/package-management/install-system-packages.sh
    @echo "📝 View log: just show-logs-last"

# Install admin-level system packages (may prompt for password)
install-system-packages-admin:
    @echo "🔐 Installing admin-level system packages..."
    @./scripts/package-management/brew/install-brew-packages.sh admin

# Install user-level system packages (no admin required)
install-system-packages-user:
    @echo "🚀 Installing user-level system packages..."
    @./scripts/package-management/brew/install-brew-packages.sh user

# Install development language packages (npm, pip, cargo, gem)
install-dev-packages:
    @echo "🔧 Installing development packages..."
    @./scripts/package-management/install-dev-packages.sh

# Install application packages (zinit, elpaca, lazy.nvim)
install-app-packages:
    @echo "📱 Installing application packages..."
    @./scripts/package-management/install-app-packages.sh

# Check for available package updates (all packages - updates registries)
check-packages:
    @echo "🔍 Checking for updates across all package types..."
    @just check-system-packages
    @echo ""
    @just check-dev-packages
    @echo ""
    @just check-app-packages

# Check for system package updates (updates OS package registries)
check-system-packages:
    @echo "🖥️ Checking system packages..."
    @./scripts/package-management/check-system-packages.sh

# Check for dev package updates (updates language package registries)
check-dev-packages:
    @echo "🔧 Checking development packages..."
    @./scripts/package-management/check-dev-packages.sh

# Check for app package updates (checks application package managers)
check-app-packages:
    @echo "📱 Checking application packages..."
    @./scripts/package-management/check-app-packages.sh

# Upgrade all packages (system, dev, and app - uses cached registries)
upgrade-packages:
    @echo "🔄 Running comprehensive package upgrade..."
    @just upgrade-system-packages
    @echo ""
    @just upgrade-dev-packages
    @echo ""
    @just upgrade-app-packages

# Upgrade system packages (both admin and user levels)
upgrade-system-packages:
    @echo "🖥️ Upgrading system packages..."
    @./scripts/package-management/upgrade-system-packages.sh

# Upgrade admin-level system packages (may prompt for password)
upgrade-system-packages-admin:
    @echo "🔐 Upgrading admin-level system packages..."
    @if command -v brew >/dev/null 2>&1; then \
        echo "🍺 Upgrading Homebrew admin packages (may require password)..."; \
        ./scripts/package-management/brew/upgrade-brew-packages.sh admin false; \
    fi

# Upgrade user-level system packages (no admin required)
upgrade-system-packages-user:
    @echo "🚀 Upgrading user-level system packages..."
    @if command -v brew >/dev/null 2>&1; then \
        echo "🍺 Upgrading Homebrew user packages..."; \
        ./scripts/package-management/brew/upgrade-brew-packages.sh user false; \
    fi

# Upgrade development language packages (npm, pip, cargo, gem)
upgrade-dev-packages:
    @echo "🔧 Upgrading development packages..."
    @./scripts/package-management/upgrade-dev-packages.sh

# Upgrade application packages (zinit, elpaca, lazy.nvim)
upgrade-app-packages:
    @echo "📱 Upgrading application packages..."
    @./scripts/package-management/upgrade-app-packages.sh

# Kill stuck brew processes (use with caution)
kill-brew-processes:
    @echo "🔪 Finding stuck brew processes..."
    @ps aux | grep -E "(brew|ruby.*brew)" | grep -v grep | head -10
    @echo ""
    @echo "⚠️  This will kill ALL brew processes. Continue? (Ctrl+C to cancel)"
    @read -p "Press ENTER to continue: "
    @pkill -f "brew" || echo "No brew processes found"
    @pkill -f "ruby.*brew" || echo "No ruby brew processes found"
    @echo "✅ Done. Wait a few seconds before running brew commands."


# Verify dev package installation completed successfully
verify-dev-package-install:
    @./scripts/package-management/verify-dev-package-install.sh

# Check system packages only (without dev packages)
check-packages-system-only:
    @./scripts/package-management/check-packages.sh

# Upgrade system packages only (without dev packages)
upgrade-packages-system-only:
    @just upgrade-packages-user
    @echo ""
    @just upgrade-packages-admin

# Export current system packages and update machine class
export-packages:
    @./scripts/package-management/export-and-update-machine.sh --update-current

# Show recent package management logs
show-logs:
    @echo "Recent package management logs:"
    @ls -lt .logs/package-*.log 2>/dev/null | head -10 || echo "No package logs found"

# Show most recent package management log
show-logs-last:
    @if ls .logs/package-*.log >/dev/null 2>&1; then \
        tail -100 `ls -t .logs/package-*.log | head -1`; \
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
    @just _check-health-with-log ".logs/health-check-$(date +%Y%m%d-%H%M%S).log" ""

# Health check with verbose output
check-health-verbose:
    @just _check-health-with-log ".logs/health-check-verbose-$(date +%Y%m%d-%H%M%S).log" "--verbose"

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
