# Dotfiles Management System - Main Interface
set dotenv-load := true

# Import contexts
import 'just/platforms.just'
import 'just/install.just'
import 'just/dev.just'

# Show main menu with clear contexts
[private]
default:
    @echo "🏠 Dotfiles Management System"
    @echo ""
    @echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    @echo "CONTEXTS:"
    @echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    @echo ""
    @echo "📦 install    - Install components on current system"
    @echo "              │ cli      - Command line tools (git, vim, tmux)"
    @echo "              │ dev      - Development tools (languages, editors)"
    @echo "              │ gui      - GUI applications (platform-specific)"
    @echo "              └ show     - Show what's included in each category"
    @echo ""
    @echo "🛠️  dev       - Development workflow & testing"
    @echo "              │ test     - Test in Docker (arch, ubuntu)"
    @echo "              │ update   - Update submodules"
    @echo "              └ validate - Run all checks"
    @echo ""
    @echo "🔗 stow      - Symlink management (in configs/)"
    @echo ""
    @echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    @echo "QUICK START:"
    @echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    @echo ""
    @echo "  just install show        - See what's available"
    @echo "  just install cli arch    - Install CLI tools for Arch"
    @echo "  just dev test ubuntu     - Test Ubuntu in Docker"

# Context shortcuts
install +args='': 
    @just install-{{args}}

dev +args='':
    @just dev-{{args}}

stow *args:
    cd configs && just {{args}}
