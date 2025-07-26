# Dotfiles Management System
set dotenv-load := true

# Environment variables (must be configured first)
platform := env_var_or_default("DOTFILES_PLATFORM", "")
level := env_var_or_default("DOTFILES_LEVEL", "")

# Show available contexts
default:
    @echo "🏠 Dotfiles Management System"
    @echo ""
    @if [ -z "{{platform}}" ] || [ -z "{{level}}" ]; then \
        echo "⚠️  Not configured yet. Run: just configure"; \
        echo ""; \
    else \
        echo "📊 Current Configuration:"; \
        echo "  Platform: {{platform}}"; \
        echo "  Level: {{level}}"; \
        echo ""; \
        echo "🚀 Quick Commands:"; \
        echo "  just bootstrap         - Bootstrap system"; \
        echo "  just stow              - Deploy configs"; \
        echo "  just health-check      - Validate configuration"; \
        echo ""; \
    fi
    @echo "🔧 Setup Commands:"
    @echo "  just configure         - Interactive configuration setup"
    @echo ""
    @echo "🔧 Available contexts:"
    @echo "  bootstrap-context - First-time setup (stow package_management)"
    @echo "  install   - Install packages (requires bootstrap first)"
    @echo "  update    - Update system packages"
    @echo "  stow-context - Manage configuration symlinks"
    @echo "  test      - Test dotfiles in Docker containers"
    @echo ""
    @echo "🔍 Other commands:"
    @echo "  health-check-log          - Run health check with logging"
    @echo "  cleanup-broken-links      - List broken symlinks (dry run)"
    @echo "  cleanup-broken-links-remove - Remove broken symlinks"

# Navigate to install context (requires package_management to be stowed)
install:
    @echo "📦 Entering install context..."
    @echo "Type 'just' to see available commands, 'exit' to return"
    @echo ""
    @cd ~/.package_management/install && $SHELL

# Navigate to update context (requires package_management to be stowed)
update:
    @echo "🔄 Entering update context..."
    @echo "Type 'just' to see available commands, 'exit' to return"
    @echo ""
    @cd ~/.package_management/update && $SHELL

# Navigate to stow context
stow-context:
    @echo "🔗 Entering stow context..."
    @echo "Type 'just' to see available commands, 'exit' to return"
    @echo ""
    @cd configs && $SHELL

# Navigate to test context
test:
    @echo "🧪 Entering test context..."
    @echo "Type 'just' to see available commands, 'exit' to return"
    @echo ""
    @cd test && $SHELL

# Bootstrap context - First-time setup
bootstrap-context:
    @echo "🚀 Bootstrap Context"
    @echo "Type 'just' to see available commands, 'exit' to return"
    @echo ""
    @cd bootstrap && $SHELL

# Health check - Validate dotfiles configuration state
health-check:
    @bash -c "source tools/dotfiles-health/dotfiles-health.sh && dotfiles_health_check"

# Health check with verbose output
health-check-verbose:
    @bash -c "source tools/dotfiles-health/dotfiles-health.sh && dotfiles_health_check --verbose"

# Health check with logging
health-check-log logfile="health-check-$(date +%Y%m%d-%H%M%S).log":
    @echo "📝 Running health check with logging to: {{logfile}}"
    @bash -c "source tools/dotfiles-health/dotfiles-health.sh && dotfiles_health_check --log {{logfile}}"

# Clean up broken symlinks (dry run)
cleanup-broken-links:
    @bash -c "source tools/dotfiles-health/dotfiles-health.sh && dotfiles_cleanup_broken_links"

# Clean up broken symlinks (actually remove)
cleanup-broken-links-remove:
    @bash -c "source tools/dotfiles-health/dotfiles-health.sh && dotfiles_cleanup_broken_links --remove"

# Configure dotfiles (interactive setup)
configure:
    #!/usr/bin/env bash
    echo "🔧 Dotfiles Configuration"
    echo ""
    echo "Available platforms:"
    echo "  1) osx     - macOS"
    echo "  2) arch    - Arch Linux"
    echo "  3) ubuntu  - Ubuntu Linux"
    echo "  4) msys2   - Windows with MSYS2"
    echo ""
    read -p "Select platform (1-4): " platform_choice
    
    case $platform_choice in
        1) PLATFORM="osx" ;;
        2) PLATFORM="arch" ;;
        3) PLATFORM="ubuntu" ;;
        4) PLATFORM="msys2" ;;
        *) echo "Invalid choice"; exit 1 ;;
    esac
    
    echo ""
    echo "Available levels:"
    echo "  1) basic   - Essential shell environment"
    echo "  2) typical - Basic + development tools"
    echo "  3) max     - Typical + GUI applications"
    echo ""
    read -p "Select level (1-3): " level_choice
    
    case $level_choice in
        1) LEVEL="basic" ;;
        2) LEVEL="typical" ;;
        3) LEVEL="max" ;;
        *) echo "Invalid choice"; exit 1 ;;
    esac
    
    echo ""
    echo "# Dotfiles Configuration" > .dotfiles.env
    echo "export DOTFILES_PLATFORM=$PLATFORM" >> .dotfiles.env
    echo "export DOTFILES_LEVEL=$LEVEL" >> .dotfiles.env
    
    echo "✅ Configuration saved to .dotfiles.env"
    echo ""
    echo "To use:"
    echo "  source .dotfiles.env"
    echo "  just bootstrap"
    echo "  just stow"

# Simple commands using environment variables
bootstrap:
    @if [ -z "{{platform}}" ] || [ -z "{{level}}" ]; then echo "❌ Not configured. Run: just configure"; exit 1; fi
    @echo "🚀 Bootstrapping {{platform}} {{level}} system..."
    @cd bootstrap && just bootstrap-{{level}}-{{platform}}

stow:
    @if [ -z "{{platform}}" ] || [ -z "{{level}}" ]; then echo "❌ Not configured. Run: just configure"; exit 1; fi
    @echo "🔗 Stowing {{platform}} {{level}} configurations..."
    @cd configs && just {{platform}} stow-{{level}}

# Bootstrap commands (delegated to bootstrap/justfile)
bootstrap-basic-arch:
    @cd bootstrap && just bootstrap-basic-arch

bootstrap-typical-arch:
    @cd bootstrap && just bootstrap-typical-arch

bootstrap-max-arch:
    @cd bootstrap && just bootstrap-max-arch

bootstrap-basic-ubuntu:
    @cd bootstrap && just bootstrap-basic-ubuntu

bootstrap-typical-ubuntu:
    @cd bootstrap && just bootstrap-typical-ubuntu

bootstrap-max-ubuntu:
    @cd bootstrap && just bootstrap-max-ubuntu

bootstrap-basic-osx:
    @cd bootstrap && just bootstrap-basic-osx

bootstrap-typical-osx:
    @cd bootstrap && just bootstrap-typical-osx

bootstrap-max-osx:
    @cd bootstrap && just bootstrap-max-osx

# Stow commands (delegated to configs/justfile)
osx-stow-basic:
    @cd configs && just osx stow-basic

osx-stow-typical:
    @cd configs && just osx stow-typical

osx-stow-max:
    @cd configs && just osx stow-max

osx-stow-basic-force:
    @cd configs && just osx stow-basic-force

osx-stow-typical-force:
    @cd configs && just osx stow-typical-force

osx-stow-max-force:
    @cd configs && just osx stow-max-force

arch-stow-basic:
    @cd configs && just arch stow-basic

arch-stow-typical:
    @cd configs && just arch stow-typical

arch-stow-max:
    @cd configs && just arch stow-max

ubuntu-stow-basic:
    @cd configs && just ubuntu stow-basic

ubuntu-stow-typical:
    @cd configs && just ubuntu stow-typical

ubuntu-stow-max:
    @cd configs && just ubuntu stow-max

# Test commands (delegated to test/justfile)
test-stow level platform:
    @cd test && just test-stow {{level}} {{platform}}

test-install level platform:
    @cd test && just test-install {{level}} {{platform}}

test-update level platform:
    @cd test && just test-update {{level}} {{platform}}

# Help aliases
help: default
h: default
usage: default