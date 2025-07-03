# Component-based installation system

# Show installation help
@install-help:
    echo "📦 Installation System"
    echo ""
    echo "Components:"
    echo "  cli   - Command line essentials"
    echo "  dev   - Development environment"
    echo "  gui   - GUI applications"
    echo ""
    echo "Usage:"
    echo "  just install show              - Show all components"
    echo "  just install cli <platform>    - Install CLI tools"
    echo "  just install dev <platform>    - Install dev tools"
    echo "  just install gui <platform>    - Install GUI apps"
    echo "  just install all <platform>    - Install everything"
    echo ""
    echo "Platforms: arch, ubuntu, osx, win-wsl, win-msys2"

# Show what's in each component
@install-show:
    echo "📋 Component Definitions"
    echo ""
    echo "━━━ CLI Tools ━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Essential command line tools:"
    echo "  • git, stow, just"
    echo "  • zsh, bash, tmux"
    echo "  • vim, nano"
    echo "  • curl, wget, rsync"
    echo "  • htop, tree, fd, ripgrep"
    echo ""
    echo "━━━ Dev Tools ━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Development environment:"
    echo "  • Editors: neovim, emacs"
    echo "  • Languages: python, node, rust, go"
    echo "  • Tools: docker, make, gcc"
    echo "  • Version managers: pyenv, nvm"
    echo ""
    echo "━━━ GUI Apps ━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Graphical applications (platform-specific):"
    echo "  • Terminals: wezterm, alacritty"
    echo "  • Browsers: firefox, chrome"
    echo "  • Editors: vscode, sublime"
    echo "  • Platform: Alfred (mac), AutoHotkey (win)"

# Install CLI tools
@install-cli platform:
    echo "📦 Installing CLI tools for {{platform}}..."
    cd configs && just stow-{{platform}}-minimal
    cd ~/.package_management/install && just install-cli-{{platform}}

# Install dev tools
@install-dev platform:
    echo "🛠️  Installing dev tools for {{platform}}..."
    just install-cli {{platform}}  # Dev depends on CLI
    cd ~/.package_management/install && just install-dev-{{platform}}

# Install GUI apps
@install-gui platform:
    echo "🖥️  Installing GUI apps for {{platform}}..."
    cd ~/.package_management/install && just install-gui-{{platform}}

# Install everything
@install-all platform:
    echo "🚀 Installing complete environment for {{platform}}..."
    just install-cli {{platform}}
    just install-dev {{platform}}
    just install-gui {{platform}}

# Platform-specific full configs
@install-home-osx:
    echo "🏠 Setting up home macOS environment..."
    just install-all osx
    # Additional home-specific configs

@install-work-osx:
    echo "🏢 Setting up work macOS environment..."
    just install-cli osx
    just install-dev osx
    # Skip personal GUI apps