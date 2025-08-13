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
    @if [ -f "$HOME/.dotfiles.env" ]; then \
        echo "📊 Current Configuration:"; \
        echo "  Platform: `source $HOME/.dotfiles.env 2>/dev/null && echo $DOTFILES_PLATFORM`"; \
        echo "  Machine class: `source $HOME/.dotfiles.env 2>/dev/null && echo $DOTFILES_MACHINE_CLASS`"; \
        echo ""; \
    else \
        echo "⚠️  Not configured yet. Start with Fresh Setup below."; \
        echo ""; \
    fi
    @echo "🚀 Fresh Setup (New Machine):"
    @echo "  just configure         - Interactive configuration (select machine class)"
    @echo "  just bootstrap         - Bootstrap system (install core tools like Python, Just)"
    @echo "  just stow              - Deploy configuration files (dotfiles symlinks)"
    @echo "  just install-packages  - Install all packages for this machine"
    @echo "  just install-packages-sudo - Install packages requiring sudo (Docker Desktop, etc.)"
    @echo ""
    @echo "🔄 Maintenance (Regular Updates):"
    @echo "  just check-packages    - Check for available package updates"
    @echo "  just upgrade-packages  - Upgrade all packages"
    @echo "  just export-packages   - Update machine class with currently installed packages"
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
    @echo "⚙️  Advanced (Fine-grained Control):"
    @echo "  just shell-into-package-manager-hub - Enter package manager hub (per-PM commands)"
    @echo "    Individual justfiles for brew, npm, pip, scoop, choco, etc."
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
    @cd package-management && just install-brew-sudo

# Check for available package updates
check-packages:
    @./scripts/package-management/check-packages.sh

# Upgrade all packages
upgrade-packages:
    @./scripts/package-management/upgrade-packages.sh

# Export current system packages and update machine class
export-packages:
    @./scripts/package-management/export-and-update-machine.sh --update-current

# Show recent package management logs
show-logs:
    @cd package-management && just show-logs

# Show most recent package management log
show-logs-last:
    @cd package-management && just show-last-log

# Enter package manager hub (focused per-PM commands)
shell-into-package-manager-hub:
    @echo "📦 Entering package manager hub..."
    @echo "Each package manager has its own focused commands and documentation"
    @echo ""
    @echo "Available package managers:"
    @echo "  just brew    - Homebrew commands (install, upgrade, clean, etc.)"
    @echo "  just npm     - NPM commands (global packages)"
    @echo "  just pip     - Python pip commands"
    @echo "  just scoop   - Windows Scoop commands"
    @echo "  just choco   - Windows Chocolatey commands"
    @echo ""
    @echo "💡 Each PM has documented commands for complex syntax (e.g., choco vs scoop)"
    @echo ""
    @cd package-management/package-managers && exec $SHELL


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
    @cd package-management && just show-config

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