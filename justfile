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

# Help aliases
help: default
h: default
usage: default