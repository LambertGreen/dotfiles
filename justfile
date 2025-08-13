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
    @echo ""
    @echo "🔄 Maintenance (Regular Updates):"
    @echo "  just check-packages    - Check for available package updates"
    @echo "  just upgrade-packages  - Upgrade all packages"
    @echo ""
    @echo "🏥 Health Check & Troubleshooting:"
    @echo "  just check-health      - Validate system health (auto-logs)"
    @echo "  just check-health-verbose - Detailed health check output"
    @echo "  just cleanup-broken-links-dry-run - List broken symlinks"
    @echo "  just cleanup-broken-links-remove  - Remove broken symlinks"
    @echo ""
    @echo "📊 Show Information:"
    @echo "  just show-packages     - Show packages configured for current machine"
    @echo "  just show-config       - Show dotfiles and machine class configuration"
    @echo "  just show-logs         - Show recent package management logs"
    @echo ""
    @echo "⚙️  Advanced (Fine-grained Control):"
    @echo "  just goto-packages     - Enter package management modal interface"
    @echo "    Available: installs, checks, upgrades - Show commands by type"
    @echo "  just install-packages-sudo - Install packages requiring sudo"
    @echo "  just export-packages   - Export current system packages"
    @echo "  just updates           - Enter update tools sub-shell"
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


# Show packages configured for current machine class
show-packages:
    @./package-management/scripts/show-packages.sh

# Install all packages (non-sudo)
install-packages:
    @./package-management/scripts/import.sh --install --interactive
    @echo ""
    @echo "📝 View log: just show-logs-last"

# Install packages requiring sudo (Docker Desktop, etc.)
install-packages-sudo:
    @cd package-management && just install-brew-sudo

# Check for available package updates
check-packages:
    @./scripts/check-packages-with-logging.sh

# Upgrade all packages
upgrade-packages:
    @./scripts/upgrade-packages-with-logging.sh

# Export current system packages (for migration/backup)
export-packages:
    @./scripts/export-and-update-machine.sh

# Update current machine class with all installed packages
update-machine-packages:
    @./scripts/export-and-update-machine.sh --update-current

# Show recent package management logs
show-logs:
    @cd package-management && just show-logs

# Show most recent package management log
show-logs-last:
    @cd package-management && just show-last-log

# Enter modal package management interface (fine-grained control)
goto-packages:
    @echo "📦 Entering package management modal interface..."
    @echo "Type 'just' to see all available commands, 'exit' to return to main shell"
    @echo "Quick start:"
    @echo "  just installs    - Show install commands"
    @echo "  just checks      - Show check commands" 
    @echo "  just upgrades    - Show upgrade commands"
    @echo ""
    @echo "Examples:"
    @echo "  just install-brew-packages  - Install only Homebrew packages"
    @echo "  just check-pip              - Check pip updates only"
    @echo "  just upgrade-npm            - Upgrade NPM packages only"
    @echo ""
    @cd package-management && exec $SHELL

# ═══════════════════════════════════════════════════════════════════════════════
# Legacy Commands (TOML-based system - deprecated)
# ═══════════════════════════════════════════════════════════════════════════════

# Legacy package installation using TOML (deprecated - use packages-* commands)
install:
    @echo "⚠️  DEPRECATED: Use 'just install-packages' for new native package management"
    @echo "Falling back to TOML-based system..."
    @echo ""
    @if [ ! -f "$HOME/.dotfiles.env" ]; then \
        echo "❌ Configuration file missing. Run: just configure"; \
        echo ""; \
        echo "💡 This will set up your platform (osx/arch/ubuntu) and machine class."; \
        exit 1; \
    fi
    @mkdir -p logs
    @source "$HOME/.dotfiles.env" && echo "📦 Installing $DOTFILES_PLATFORM packages using TOML-based package management..."
    @echo "📝 Logging to: logs/install-$(date +%Y%m%d-%H%M%S).log"
    @echo "⚠️  DEPRECATED: Use 'just install-packages' for new native package management"
    @echo "This will install packages using the new machine class system"
    @echo ""
    @./package-management/scripts/import.sh --install


# Legacy update check (deprecated - use packages-* commands)
update-check:
    @echo "⚠️  DEPRECATED: Use 'just check-packages' for new native package management"
    @echo "Falling back to TOML-based system..."
    @echo ""
    @if [ ! -f "$HOME/.dotfiles.env" ]; then \
        echo "❌ Platform not configured. Run: just configure"; \
        exit 1; \
    fi
    @source "$HOME/.dotfiles.env" && echo "🔍 Checking for $DOTFILES_PLATFORM package updates..."
    @echo "⚠️  DEPRECATED: Use 'just check-packages' for new native package management"
    @echo "This will check updates using the new machine class system"
    @echo ""
    @cd package-management && just update-check

# Legacy upgrade command (deprecated - use packages-* commands)
update-upgrade:
    @echo "⚠️  DEPRECATED: Use 'just upgrade-packages' for new native package management"
    @echo "Falling back to TOML-based system..."
    @echo ""
    @if [ ! -f "$HOME/.dotfiles.env" ]; then \
        echo "❌ Platform not configured. Run: just configure"; \
        exit 1; \
    fi
    @echo "⚠️  WARNING: This will upgrade all configured packages!"
    @echo "Run 'just update-check' first to see what will be upgraded."
    @echo ""
    @bash -c 'read -p "Continue with upgrade? (y/N): " confirm; if [[ "$confirm" != [yY] && "$confirm" != [yY][eE][sS] ]]; then echo "Cancelled."; exit 1; fi'
    @echo ""
    @source "$HOME/.dotfiles.env" && echo "🔄 Upgrading $DOTFILES_PLATFORM packages..."
    @echo "⚠️  DEPRECATED: Use 'just upgrade-packages' for new native package management"
    @echo "This will update packages using the new machine class system"
    @echo ""
    @cd package-management && just update-all

# Opens a sub-shell with platform-specific update tools
updates:
    @source "$HOME/.dotfiles.env" && echo "🔧 Opening update tools for $DOTFILES_PLATFORM..."
    @echo "Type 'just' to see available commands, 'exit' to return to main shell"
    @echo ""
    @echo "⚠️  DEPRECATED: Use 'just goto-packages' for new package management modal interface"
    @echo "This provides fine-grained control over package operations"
    @echo ""
    @cd package-management && exec $SHELL



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
    @export DOTFILES_DIR="{{justfile_directory()}}" && bash -c "set -a && source $HOME/.dotfiles.env && set +a && source tools/dotfiles-health/dotfiles-health.sh && dotfiles_check_health {{flags}} --log {{logfile}}"

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
    @bash -c "export DOTFILES_DIR={{justfile_directory()}} && source tools/dotfiles-health/dotfiles-health.sh && dotfiles_cleanup_broken_links" 2>&1 || true

# Remove broken symlinks
cleanup-broken-links-remove:
    @bash -c "source tools/dotfiles-health/dotfiles-health.sh && dotfiles_cleanup_broken_links --remove"

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
    @source "$HOME/.dotfiles.env" && ./scripts/stow-with-logging.sh "$DOTFILES_PLATFORM"



# Help aliases
[private]
help: default

[private]
h: default

[private]
usage: default