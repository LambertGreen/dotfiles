# Dotfiles Management System
# Note: Configuration loaded from ~/.dotfiles.env via shell sourcing in commands

# Environment variables (will be loaded from ~/.dotfiles.env in commands)
platform := env_var_or_default("DOTFILES_PLATFORM", "")

# Set DOTFILES_DIR for all commands
export DOTFILES_DIR := justfile_directory()

# Show configuration and available commands
[private]
default:
    @./scripts/show-config.sh
    @echo ""
    @echo "🚀 New user? Start with: just configure → just bootstrap → just stow → just install"
    @echo ""
    @just --list

# ═══════════════════════════════════════════════════════════════════════════════
# Core User Commands
# ═══════════════════════════════════════════════════════════════════════════════

# Interactive configuration (select machine class)
[group('1-🚀-Setup')]
configure:
    @{{ if os() == "windows" { "C:/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -NoProfile -ExecutionPolicy Bypass -File configure.ps1" } else { "./configure.sh" } }}

# Bootstrap system (install core tools)
[group('1-🚀-Setup')]
bootstrap:
    @{{ if os() == "windows" { "C:/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -NoProfile -ExecutionPolicy Bypass -File bootstrap.ps1" } else { "./bootstrap.sh" } }}

# Deploy configuration files
[group('1-🚀-Setup')]
stow:
    @if [ ! -f "$HOME/.dotfiles.env" ]; then \
        echo "❌ Platform not configured. Run: just configure"; \
        exit 1; \
    fi
    @./scripts/stow/stow-dotfiles.sh

# Install packages via all package managers
[group('2-📦-Package-Management')]
install:
    @echo "📦 Installing packages for current machine class..."
    @python3 -m src.dotfiles_pm.pm install --category system
    @echo ""
    @python3 -m src.dotfiles_pm.pm install --category dev
    @echo ""
    @python3 -m src.dotfiles_pm.pm install --category app
    @echo ""
    @echo "✅ Package installation complete"

# Check for updates across package managers
[group('2-📦-Package-Management')]
check:
    @echo "🔍 Checking for package updates (interactive)..."
    @python3 -m src.dotfiles_pm.pm check

# Upgrade packages across package managers
[group('2-📦-Package-Management')]
upgrade:
    @echo "🔄 Upgrading packages (interactive)..."
    @python3 -m src.dotfiles_pm.pm upgrade

# Enable/disable package managers
[group('2-📦-Package-Management')]
register-package-managers:
    @echo "📦 Registering available package managers..."
    @python3 -m src.dotfiles_pm.pm configure

# Show available package managers
[group('2-📦-Package-Management')]
list-package-managers:
    @python3 -m src.dotfiles_pm.pm list

# Run system health validation
[group('3-🏥-System')]
health-check:
    @echo "🏥 Running health check..."
    @bash -c "source scripts/health/dotfiles-health.sh && dotfiles_health_check"

# Show current configuration
[group('4-ℹ️-Info')]
show-config:
    @./scripts/show-config.sh

# Show package counts summary
[group('4-ℹ️-Info')]
package-summary:
    @./scripts/package-management/show-package-stats.sh

# Show configuration and all available commands
[private]
help:
    @./scripts/show-config.sh
    @echo ""
    @echo "🚀 New user? Start with: just configure → just bootstrap → just stow → just install"
    @echo ""
    @just --list

# Short alias for help
[private]
h: help

# ═══════════════════════════════════════════════════════════════════════════════
# Modal Context Navigation
# ═══════════════════════════════════════════════════════════════════════════════

# Enter testing context (Docker + Python tests)
[group('5-🔧-Contexts')]
testing:
    @echo "🧪 Entering testing context..."
    @echo "Use 'just' to see available test commands"
    @cd test && exec $SHELL

# Enter debugging context (health, logs, troubleshooting)
[group('5-🔧-Contexts')]
debugging:
    @echo "🔍 Entering debugging context..."
    @echo "Use 'just' to see available debug commands"
    @cd debug && exec $SHELL

# Enter package managers context (granular PM control)
[group('5-🔧-Contexts')]
package-managers:
    @echo "📦 Entering package managers context..."
    @echo "Use 'just' to see available PM commands"
    @cd package-managers && exec $SHELL
