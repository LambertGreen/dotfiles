# Dotfiles Management System
set dotenv-load := true

# Show available contexts
default:
    @echo "🏠 Dotfiles Management System"
    @echo ""
    @echo "Available contexts:"
    @echo "  bootstrap - First-time setup (stow package_management)"
    @echo "  install   - Install packages (requires bootstrap first)"
    @echo "  update    - Update system packages"
    @echo "  stow      - Manage configuration symlinks"
    @echo "  test      - Test dotfiles in Docker containers"
    @echo ""
    @echo "Available commands:"
    @echo "  health-check              - Validate dotfiles configuration state"
    @echo "  health-check-log          - Run health check with logging"
    @echo "  cleanup-broken-links      - List broken symlinks (dry run)"
    @echo "  cleanup-broken-links-remove - Remove broken symlinks"
    @echo ""
    @echo "Usage:"
    @echo "  just <context>         - Enter context"

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
stow:
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
bootstrap:
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