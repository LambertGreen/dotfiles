# Dotfiles Management System
set dotenv-load := true

# Environment variables (must be configured first)
platform := env_var_or_default("DOTFILES_PLATFORM", "")

# Set DOTFILES_DIR for all commands
export DOTFILES_DIR := justfile_directory()

# Show available commands
[private]
default:
    @echo "🏠 Dotfiles Management System"
    @echo ""
    @if [ -z "{{platform}}" ]; then \
        echo "⚠️  Not configured yet. Run: just configure"; \
        echo ""; \
    else \
        echo "📊 Current Configuration:"; \
        echo "  Platform: {{platform}}"; \
        echo "  Run 'just show-config' to see enabled categories"; \
        echo ""; \
        echo "🚀 Main Commands:"; \
        echo "  just bootstrap         - Bootstrap system (install core tools)"; \
        echo "  just stow              - Deploy configuration files"; \
        echo "  just install           - Install packages based on your categories"; \
        echo "  just update-check      - Check for available package updates"; \
        echo "  just update-upgrade    - Upgrade all configured packages"; \
        echo "  just check-health      - Validate system health (auto-logs)"; \
        echo ""; \
    fi
    @echo "🔧 Setup Commands:"
    @echo "  just configure         - Interactive configuration (profiles or custom categories)"
    @echo "  just show-config       - Show current configuration"
    @echo ""
    @echo "🔧 Specialized Commands:"
    @echo "  just updates                   - Opens a sub-shell with platform-specific update tools"
    @echo "  just testing                   - Opens a sub-shell with testing and validation tools"
    @echo ""
    @echo "🧪 Quick Test Commands:"
    @echo "  just test-arch                 - Quick test Arch configuration"
    @echo "  just test-ubuntu               - Quick test Ubuntu configuration" 
    @echo ""
    @echo "🔍 Other Commands:"
    @echo "  just check-health-verbose      - Health check with detailed output"
    @echo "  just cleanup-broken-links-dry-run - List broken symlinks (dry run)"
    @echo "  just cleanup-broken-links-remove  - Remove broken symlinks"

# Install packages based on your categories
install:
    @if [ -z "{{platform}}" ]; then \
        echo "❌ Platform not configured. Run: just configure"; \
        echo ""; \
        echo "💡 This will set up your platform (osx/arch/ubuntu) and package categories."; \
        exit 1; \
    fi
    @if [ ! -f ".dotfiles.env" ]; then \
        echo "❌ Configuration file missing. Run: just configure"; \
        exit 1; \
    fi
    @echo "📦 Installing {{platform}} packages using TOML-based package management..."
    @export DOTFILES_DIR="{{justfile_directory()}}" && export DOTFILES_PLATFORM="{{platform}}" && bash -c "source tools/package-management/scripts/package-management-config.sh && package_install"


# Check for available package updates (safe to run)
update-check:
    @if [ -z "{{platform}}" ]; then \
        echo "❌ Platform not configured. Run: just configure"; \
        exit 1; \
    fi
    @echo "🔍 Checking for {{platform}} package updates..."
    @export DOTFILES_DIR="{{justfile_directory()}}" && export DOTFILES_PLATFORM="{{platform}}" && bash -c "source tools/package-management/scripts/package-management-config.sh && package_update_check"

# Upgrade all configured packages (requires careful consideration)
update-upgrade:
    @if [ -z "{{platform}}" ]; then \
        echo "❌ Platform not configured. Run: just configure"; \
        exit 1; \
    fi
    @echo "⚠️  WARNING: This will upgrade all configured packages!"
    @echo "Run 'just update-check' first to see what will be upgraded."
    @echo ""
    @bash -c 'read -p "Continue with upgrade? (y/N): " confirm; if [[ "$confirm" != [yY] && "$confirm" != [yY][eE][sS] ]]; then echo "Cancelled."; exit 1; fi'
    @echo ""
    @echo "🔄 Upgrading {{platform}} packages..."
    @export DOTFILES_DIR="{{justfile_directory()}}" && export DOTFILES_PLATFORM="{{platform}}" && bash -c "source tools/package-management/scripts/package-management-config.sh && package_update"

# Opens a sub-shell with platform-specific update tools
updates:
    @echo "🔧 Opening update tools for {{platform}}..."
    @echo "Type 'just' to see available commands, 'exit' to return to main shell"
    @echo ""
    @if [ -f "tools/package-management/update-recipes/{{platform}}/justfile" ]; then \
        cd tools/package-management/update-recipes/{{platform}} && exec $SHELL; \
    else \
        echo "❌ No update tools available for platform: {{platform}}"; \
        echo "Expected: tools/package-management/update-recipes/{{platform}}/justfile"; \
        exit 1; \
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
    @just _check-health-with-log "health-check-$(date +%Y%m%d-%H%M%S).log" ""

# Health check with verbose output
check-health-verbose:
    @just _check-health-with-log "health-check-verbose-$(date +%Y%m%d-%H%M%S).log" "--verbose"

# Internal helper for health checks with logging
[private]
_check-health-with-log logfile flags:
    @echo "🏥 Running health check with logging to: {{logfile}}"
    @export DOTFILES_DIR="{{justfile_directory()}}" && export DOTFILES_PLATFORM="{{platform}}" && bash -c "set -a && source .dotfiles.env && set +a && source tools/dotfiles-health/dotfiles-health.sh && dotfiles_check_health {{flags}} --log {{logfile}}"

# Show current configuration
show-config:
    @if [ -z "{{platform}}" ]; then \
        echo "❌ Platform not configured. Run: just configure"; \
        exit 1; \
    fi
    @if [ ! -f ".dotfiles.env" ]; then \
        echo "❌ Configuration file missing. Run: just configure"; \
        exit 1; \
    fi
    @export DOTFILES_DIR="{{justfile_directory()}}" && export DOTFILES_PLATFORM="{{platform}}" && bash -c "source tools/package-management/scripts/package-management-config.sh && package_show_config"

# List broken symlinks (dry run)
cleanup-broken-links-dry-run:
    @bash -c "source tools/dotfiles-health/dotfiles-health.sh && dotfiles_cleanup_broken_links"

# Remove broken symlinks
cleanup-broken-links-remove:
    @bash -c "source tools/dotfiles-health/dotfiles-health.sh && dotfiles_cleanup_broken_links --remove"

# Interactive configuration (profiles or custom categories)
configure:
    @./configure.sh


# Bootstrap system (install core tools)
bootstrap:
    @./bootstrap.sh

# Deploy configuration files
stow:
    @if [ -z "{{platform}}" ]; then \
        echo "❌ Platform not configured. Run: just configure"; \
        exit 1; \
    fi
    @echo "🔗 Stowing {{platform}} configurations using new structure..."
    @export DOTFILES_DIR="{{justfile_directory()}}" && export DOTFILES_PLATFORM="{{platform}}" && bash -c "source tools/package-management/scripts/package-management-config.sh && package_stow"



# Help aliases
[private]
help: default

[private]
h: default

[private]
usage: default