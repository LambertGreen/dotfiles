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
    @. "$HOME/.dotfiles.env" && ./scripts/stow/stow.sh "$DOTFILES_PLATFORM"

# Install packages via all package managers
[group('2-📦-Package-Management')]
install:
    @echo "📦 Installing packages for current machine class..."
    @if [ -f "$HOME/.dotfiles.env" ]; then . "$HOME/.dotfiles.env"; fi && python3 -m src.dotfiles_pm.pm install || \
    if [ $$? -eq 41 ]; then \
        echo "❌ Brew locked. Fix with: just doctor-brew-lock"; \
        exit 1; \
    fi

# Update package registries and check for available updates
[group('2-📦-Package-Management')]
update:
    @echo "🔄 Updating package registries and checking for updates..."
    @if [ -f "$HOME/.dotfiles.env" ]; then . "$HOME/.dotfiles.env"; fi && python3 -m src.dotfiles_pm.pm check || \
    if [ $$? -eq 41 ]; then \
        echo "❌ Brew locked. Fix with: just doctor-brew-lock"; \
        exit 1; \
    fi

# Upgrade packages across package managers
[group('2-📦-Package-Management')]
upgrade:
    @echo "🔄 Upgrading packages (interactive)..."
    @if [ -f "$HOME/.dotfiles.env" ]; then . "$HOME/.dotfiles.env"; fi && python3 -m src.dotfiles_pm.pm upgrade || \
    if [ $$? -eq 41 ]; then \
        echo "❌ Brew locked. Fix with: just doctor-brew-lock"; \
        exit 1; \
    fi

# Enable/disable package managers
[group('2-📦-Package-Management')]
register-package-managers:
    @echo "📦 Registering available package managers..."
    @python3 -m src.dotfiles_pm.pm configure || \
    if [ $$? -eq 41 ]; then \
        echo "❌ Brew locked. Fix with: just doctor-brew-lock"; \
        exit 1; \
    fi

# Show available package managers
[group('2-📦-Package-Management')]
list-package-managers:
    @python3 -m src.dotfiles_pm.pm list || \
    if [ $$? -eq 41 ]; then \
        echo "❌ Brew locked. Fix with: just doctor-brew-lock"; \
        exit 1; \
    fi


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

# Enter debugging context (health, logs, troubleshooting)
[group('6-🔧-Contexts')]
debugging:
    @echo "🔍 Entering debugging context..."
    @echo "Use 'just' to see available debug commands"
    @cd debug && exec $SHELL

# Enter package managers context (granular PM control)
[group('6-🔧-Contexts')]
package-managers:
    @echo "📦 Entering package managers context..."
    @echo "Use 'just' to see available PM commands"
    @cd package-managers && exec $SHELL

# Enter testing context (all testing commands)
[group('5-🧪-Testing')]
goto-testing:
    @echo "🧪 Entering testing context..."
    @echo "Use 'just' to see all available testing commands"
    @cd tests && exec $SHELL

# ═══════════════════════════════════════════════════════════════════════════════
# Doctor Commands (System Repair & Diagnostics)
# ═══════════════════════════════════════════════════════════════════════════════

# Diagnose and fix Homebrew lock issues
[group('7-👩‍⚕️-Doctor')]
doctor-brew-lock:
    @echo "👩‍⚕️ Diagnosing Homebrew lock issue..."
    @echo "1. Checking current status..."
    @python3 -m src.dotfiles_pm.pms.brew_utils status
    @echo ""
    @echo "2. Attempting graceful process termination..."
    @python3 -m src.dotfiles_pm.pms.brew_utils kill
    @echo ""
    @echo "3. Testing availability..."
    @if brew --version >/dev/null 2>&1; then \
        echo "✅ Homebrew is now available"; \
        echo "💡 Try your original command again"; \
    else \
        echo "❌ Homebrew still locked - trying force kill..."; \
        python3 -m src.dotfiles_pm.pms.brew_utils kill-force; \
        echo ""; \
        echo "4. Final cleanup..."; \
        brew cleanup --prune=all 2>/dev/null || echo "   Cleanup skipped (still locked)"; \
        echo ""; \
        if brew --version >/dev/null 2>&1; then \
            echo "✅ Homebrew recovered successfully"; \
        else \
            echo "❌ Manual intervention required:"; \
            echo "   • Check for stale lock files in /opt/homebrew/var/homebrew/locks/"; \
            echo "   • Run: brew doctor"; \
            echo "   • Consider reboot if issue persists"; \
        fi; \
    fi

# Check system health (migrated from check-health)
[group('7-👩‍⚕️-Doctor')]
doctor-system-health:
    @echo "👩‍⚕️ Running comprehensive system health check..."
    @bash -c "source scripts/health/dotfiles-health.sh && dotfiles_check_health"

# Diagnose and fix broken symlinks
[group('7-👩‍⚕️-Doctor')]
doctor-broken-links:
    @echo "👩‍⚕️ Diagnosing broken symlinks..."
    @echo "Scanning for broken symlinks (dry-run)..."
    @bash -c "source scripts/health/dotfiles-health.sh && dotfiles_cleanup_broken_links"
    @echo ""
    @echo "💡 To remove broken symlinks, run: just doctor-broken-links-fix"

# Fix broken symlinks (destructive)
[group('7-👩‍⚕️-Doctor')]
doctor-broken-links-fix:
    @echo "👩‍⚕️ Fixing broken symlinks..."
    @echo "⚠️  This will remove broken symlinks permanently!"
    @read -p "Continue? (y/N): " confirm && [ "$$confirm" = "y" ] || exit 1
    @bash -c "source scripts/health/dotfiles-health.sh && dotfiles_cleanup_broken_links --remove"

# ═══════════════════════════════════════════════════════════════════════════════
# Legacy Health Commands (deprecated - use doctor-* commands)
# ═══════════════════════════════════════════════════════════════════════════════

# Validate system health (deprecated: use doctor-system-health)
[group('3-🏥-System')]
check-health:
    @echo "⚠️  Deprecated: Use 'just doctor-system-health' instead"
    @bash -c "source scripts/health/dotfiles-health.sh && dotfiles_check_health"

# Find broken symlinks (deprecated: use doctor-broken-links)
[group('3-🏥-System')]
cleanup-broken-links-dry-run:
    @echo "⚠️  Deprecated: Use 'just doctor-broken-links' instead"
    @bash -c "source scripts/health/dotfiles-health.sh && dotfiles_cleanup_broken_links"

# Remove broken symlinks (deprecated: use doctor-broken-links-fix)
[group('3-🏥-System')]
cleanup-broken-links-remove:
    @echo "⚠️  Deprecated: Use 'just doctor-broken-links-fix' instead"
    @bash -c "source scripts/health/dotfiles-health.sh && dotfiles_cleanup_broken_links --remove"
