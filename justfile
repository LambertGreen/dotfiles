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
    @./scripts/show-config.sh
    @echo "🚀 Fresh Setup (New Machine):"
    @echo "  just configure                      - Interactive configuration (select machine class)"
    @echo "  just bootstrap                      - Bootstrap system (install core tools like Python, Just)"
    @echo "  just stow                          - Deploy configuration files (dotfiles symlinks)"
    @echo "  just install-packages              - Install all packages (system → dev → app)"
    @echo ""
    @echo "📦 System Packages (brew, apt, pacman):"
    @echo "  just install-system-packages       - Install system packages (admin → user)"
    @echo "  just check-system-packages         - Check system packages for updates"
    @echo "  just upgrade-system-packages       - Upgrade system packages"
    @echo "  just install-system-packages-admin - Install admin packages (may prompt for password)"
    @echo "  just install-system-packages-user  - Install user packages (no admin required)"
    @echo ""
    @echo "🔧 Development Packages (npm, pip, cargo, gem):"
    @echo "  just install-dev-packages          - Install development language packages"
    @echo "  just check-dev-packages            - Check dev packages for updates"
    @echo "  just upgrade-dev-packages          - Upgrade development packages"
    @echo "  just init-dev-packages             - Initialize dev packages (first-time setup)"
    @echo "  just verify-dev-package-install    - Verify dev package installation"
    @echo ""
    @echo "📱 Application Packages (zinit, elpaca, lazy.nvim):"
    @echo "  just install-app-packages          - Install application package managers"
    @echo "  just check-app-packages            - Check app packages for updates"
    @echo "  just upgrade-app-packages          - Upgrade application packages"
    @echo ""
    @echo "🔄 Unified Package Operations:"
    @echo "  just register-pms                  - Register/enable package managers"
    @echo "  just check-packages                - Check all packages (with PM selection)"
    @echo "  just upgrade-packages              - Upgrade all packages (with PM selection)"
    @echo "  just export-packages               - Update machine class with installed packages"
    @echo ""
    @echo "🏥 Health Check & Troubleshooting:"
    @echo "  just check-health                     - Validate system health (auto-logs)"
    @echo "  just check-health-verbose             - Detailed health check output"
    @echo "  just cleanup-broken-links-dry-run     - List broken symlinks"
    @echo "  just cleanup-broken-links-remove      - Remove broken symlinks"
    @echo ""
    @echo "📊 Log Analysis:"
    @echo "  just logs                             - List recent log files"
    @echo "  just logs-summary                     - Show summary of latest log"
    @echo "  just logs-errors                      - Show error messages from latest log"
    @echo "  just logs-timing                      - Show timing analysis of latest log"
    @echo "  just logs-view [file]                 - Interactive log viewer"
    @echo "  just kill-brew-processes              - Kill stuck brew processes (use with caution)"
    @echo ""
    @echo "📊 Show Information:"
    @echo "  just show-package-list                - Show full list of packages (pipeable to pager)"
    @echo "  just show-package-stats               - Show package counts summary"
    @echo "  just show-config                      - Show dotfiles and machine class configuration"
    @echo "  just show-logs                        - Show recent package management logs"
    @echo ""
    @echo "🛠️  Project Development & Testing:"
    @echo "  just testing           - Enter testing sub-shell (Docker test commands)"
    @echo "  just test-arch         - Quick test Arch configuration"
    @echo "  just test-ubuntu       - Quick test Ubuntu configuration"
    @echo ""
    @echo "📁 Logs: .logs/ directory - cleanup with: trash logs"

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

# Install all packages (system, dev, and app packages)
install-packages:
    @echo "📦 Installing all packages for current machine class..."
    @just install-system-packages
    @echo ""
    @just install-dev-packages
    @echo ""
    @just install-app-packages
    @echo ""
    @echo "✅ Package installation complete"

# Install system packages (using Python system)
install-system-packages:
    @echo "🖥️ Installing system packages..."
    @python3 -m src.dotfiles_pm.pm install --category system

# Install admin-level system packages (using Python system)
install-system-packages-admin:
    @echo "🔐 Installing admin-level system packages..."
    @python3 -m src.dotfiles_pm.pm install brew --level admin

# Install user-level system packages (using Python system)
install-system-packages-user:
    @echo "🚀 Installing user-level system packages..."
    @python3 -m src.dotfiles_pm.pm install brew --level user

# Install development language packages (using Python system)
install-dev-packages:
    @echo "🔧 Installing development packages..."
    @python3 -m src.dotfiles_pm.pm install --category dev

# Install application packages (using Python system)
install-app-packages:
    @echo "📱 Installing application packages..."
    @python3 -m src.dotfiles_pm.pm install --category app

# Check for available package updates (all packages - with PM selection)
check-packages:
    @echo "🔍 Unified package checking with PM selection..."
    @python3 -m src.dotfiles_pm.pm check

# Check for system package updates (using Python system)
check-system-packages:
    @echo "🖥️ Checking system packages..."
    @python3 -m src.dotfiles_pm.pm check brew apt pacman choco winget scoop

# Check for dev package updates (using Python system)
check-dev-packages:
    @echo "🔧 Checking development packages..."
    @python3 -m src.dotfiles_pm.pm check npm pip pipx cargo gem

# Check for app package updates (using Python system)
check-app-packages:
    @echo "📱 Checking application packages..."
    @python3 -m src.dotfiles_pm.pm check emacs zinit neovim

# Upgrade all packages (system, dev, and app - with PM selection)
upgrade-packages:
    @echo "🔄 Unified package upgrading with PM selection..."
    @python3 -m src.dotfiles_pm.pm upgrade

# Upgrade system packages (using Python system)
upgrade-system-packages:
    @echo "🖥️ Upgrading system packages..."
    @python3 -m src.dotfiles_pm.pm upgrade brew apt pacman choco winget scoop

# Upgrade admin-level system packages (may prompt for password)
upgrade-system-packages-admin:
    @echo "🔐 Upgrading admin-level system packages..."
    @if command -v brew >/dev/null 2>&1; then \
        echo "🍺 Upgrading Homebrew admin packages (may require password)..."; \
        ./scripts/package-management/brew/upgrade-brew-packages.sh admin false; \
    fi

# Upgrade user-level system packages (no admin required)
upgrade-system-packages-user:
    @echo "🚀 Upgrading user-level system packages..."
    @if command -v brew >/dev/null 2>&1; then \
        echo "🍺 Upgrading Homebrew user packages..."; \
        ./scripts/package-management/brew/upgrade-brew-packages.sh user false; \
    fi

# Upgrade development language packages (using Python system)
upgrade-dev-packages:
    @echo "🔧 Upgrading development packages..."
    @python3 -m src.dotfiles_pm.pm upgrade npm pip pipx cargo gem

# Upgrade application packages (using Python system)
upgrade-app-packages:
    @echo "📱 Upgrading application packages..."
    @python3 -m src.dotfiles_pm.pm upgrade emacs zinit neovim

# Kill stuck brew processes (use with caution)
kill-brew-processes:
    @echo "🔪 Finding stuck brew processes..."
    @ps aux | grep -E "(brew|ruby.*brew)" | grep -v grep | head -10
    @echo ""
    @echo "⚠️  This will kill ALL brew processes. Continue? (Ctrl+C to cancel)"
    @read -p "Press ENTER to continue: "
    @pkill -f "brew" || echo "No brew processes found"
    @pkill -f "ruby.*brew" || echo "No ruby brew processes found"
    @echo "✅ Done. Wait a few seconds before running brew commands."


# Verify dev package installation completed successfully
verify-dev-package-install:
    @./scripts/package-management/verify-dev-package-install.sh

# Check system packages only (without dev packages)
check-packages-system-only:
    @python3 -m src.dotfiles_pm.pm check

# Upgrade system packages only (without dev packages)
upgrade-packages-system-only:
    @just upgrade-packages-user
    @echo ""
    @just upgrade-packages-admin

# Export current system packages and update machine class
export-packages:
    @./scripts/package-management/export-and-update-machine.sh --update-current

# Show recent package management logs
show-logs:
    @echo "Recent package management logs:"
    @ls -lt .logs/package-*.log 2>/dev/null | head -10 || echo "No package logs found"

# Show most recent package management log
show-logs-last:
    @if ls .logs/package-*.log >/dev/null 2>&1; then \
        tail -100 `ls -t .logs/package-*.log | head -1`; \
    else \
        echo "No package logs found"; \
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
    @just _check-health-with-log ".logs/health-check-$(date +%Y%m%d-%H%M%S).log" ""

# Health check with verbose output
check-health-verbose:
    @just _check-health-with-log ".logs/health-check-verbose-$(date +%Y%m%d-%H%M%S).log" "--verbose"

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
    @if [[ -f ~/.dotfiles.env ]]; then \
        source ~/.dotfiles.env; \
        echo "    Location: machine-classes/${DOTFILES_MACHINE_CLASS}/"; \
        echo "    Package managers: ${DOTFILES_PACKAGE_MANAGERS:-not set}"; \
    fi

# List broken symlinks (dry run)
cleanup-broken-links-dry-run:
    @echo "🔍 Finding broken symlinks in dotfiles..."
    @bash -c "export DOTFILES_DIR={{justfile_directory()}} && source scripts/health/dotfiles-health.sh && dotfiles_cleanup_broken_links" 2>&1 || true

# Remove broken symlinks
cleanup-broken-links-remove:
    @bash -c "source scripts/health/dotfiles-health.sh && dotfiles_cleanup_broken_links --remove"

# Interactive configuration (select machine class)
configure:
    @{{ if os() == "windows" { "C:/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -NoProfile -ExecutionPolicy Bypass -File configure.ps1" } else { "./configure.sh" } }}

# Bootstrap system (install core tools)
bootstrap:
    @{{ if os() == "windows" { "C:/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -NoProfile -ExecutionPolicy Bypass -File bootstrap.ps1" } else { "./bootstrap.sh" } }}

# Deploy configuration files
stow:
    @if [ ! -f "$HOME/.dotfiles.env" ]; then \
        echo "❌ Platform not configured. Run: just configure"; \
        exit 1; \
    fi
    @bash -c 'source "$HOME/.dotfiles.env" && ./scripts/stow/stow.sh "$DOTFILES_PLATFORM"'



# Log Analysis Commands

# List recent log files
logs:
    @source ./scripts/package-management/shared/log-utils.sh && list_logs

# Show summary of latest log
logs-summary file="":
    @source ./scripts/package-management/shared/log-utils.sh && log_summary {{file}}

# Show error messages from latest log
logs-errors file="":
    @source ./scripts/package-management/shared/log-utils.sh && filter_by_level ERROR {{file}}

# Show timing analysis of latest log
logs-timing file="":
    @source ./scripts/package-management/shared/log-utils.sh && log_timing {{file}}

# Interactive log viewer
logs-view file="":
    @source ./scripts/package-management/shared/log-utils.sh && view_log {{file}}

# Show only dotfiles log entries (filter out external tool output)
logs-dotfiles file="":
    @source ./scripts/package-management/shared/log-utils.sh && filter_dotfiles_logs {{file}}

# Help aliases
[private]
help: default

[private]
h: default

# ═══════════════════════════════════════════════════════════════════════════════
# Conditional Package Manager Recipes (only show if PM is installed)
# ═══════════════════════════════════════════════════════════════════════════════

# Check brew packages (only available if brew is installed)
[group('PM-specific')]
check-brew-packages:
    #!/usr/bin/env bash
    if command -v brew >/dev/null 2>&1; then
        echo "🍺 Checking Homebrew packages..."
        python3 -m src.dotfiles_pm.pm check brew
    else
        echo "❌ Homebrew not installed"
        exit 1
    fi

# Upgrade brew packages (only available if brew is installed)
[group('PM-specific')]
upgrade-brew-packages:
    #!/usr/bin/env bash
    if command -v brew >/dev/null 2>&1; then
        echo "🍺 Upgrading Homebrew packages..."
        python3 -m src.dotfiles_pm.pm upgrade brew
    else
        echo "❌ Homebrew not installed"
        exit 1
    fi

# Check npm packages (only available if npm is installed)
[group('PM-specific')]
check-npm-packages:
    #!/usr/bin/env bash
    if command -v npm >/dev/null 2>&1; then
        echo "📦 Checking npm packages..."
        python3 -m src.dotfiles_pm.pm check npm
    else
        echo "❌ npm not installed"
        exit 1
    fi

# Upgrade npm packages (only available if npm is installed)
[group('PM-specific')]
upgrade-npm-packages:
    #!/usr/bin/env bash
    if command -v npm >/dev/null 2>&1; then
        echo "📦 Upgrading npm packages..."
        python3 -m src.dotfiles_pm.pm upgrade npm
    else
        echo "❌ npm not installed"
        exit 1
    fi

# Check pip packages (only available if pip3 is installed)
[group('PM-specific')]
check-pip-packages:
    #!/usr/bin/env bash
    if command -v pip3 >/dev/null 2>&1; then
        echo "🐍 Checking pip packages..."
        python3 -m src.dotfiles_pm.pm check pip
    else
        echo "❌ pip3 not installed"
        exit 1
    fi

# Upgrade pip packages (only available if pip3 is installed)
[group('PM-specific')]
upgrade-pip-packages:
    #!/usr/bin/env bash
    if command -v pip3 >/dev/null 2>&1; then
        echo "🐍 Upgrading pip packages..."
        python3 -m src.dotfiles_pm.pm upgrade pip
    else
        echo "❌ pip3 not installed"
        exit 1
    fi

# Test recipe that's only available when test PMs exist
[group('Testing')]
test-fake-pms:
    #!/usr/bin/env bash
    export PATH="$(pwd)/test:$PATH"
    if command -v fake-pm1 >/dev/null 2>&1 && command -v fake-pm2 >/dev/null 2>&1; then
        echo "🧪 Testing with fake package managers..."
        echo "FakePM1 version: $(fake-pm1 version)"
        echo "FakePM2 version: $(fake-pm2 version)"
        echo "✅ Fake PMs are working"
    else
        echo "❌ Fake PMs not found (run from project root)"
        exit 1
    fi

# Run pytest suite
[group('Testing')]
test:
    @echo "🧪 Running pytest suite..."
    python3 -m pytest tests/ -v

# Run pytest with coverage
[group('Testing')]
test-coverage:
    @echo "🧪 Running pytest with coverage..."
    python3 -m pytest tests/ --cov=scripts --cov-report=term-missing

# List available package managers
[group('Package Info')]
list-pms:
    @python3 -m src.dotfiles_pm.pm list

# Register/configure which package managers are enabled/disabled
# Use this after installing packages to enable/disable specific PMs
register-pms:
    @echo "📦 Registering available package managers..."
    @python3 -m src.dotfiles_pm.pm configure

# Alias for register-pms
[group('Package Info')]
configure-pms: register-pms

# Run end-to-end tests with fake package managers
[group('Testing')]
test-e2e:
    #!/usr/bin/env bash
    echo "🧪 Running end-to-end tests with fake PMs..."
    export PATH="./test:$PATH"
    export DOTFILES_PM_ONLY_FAKES="true"  # Only use fake PMs for testing
    python3 test/test_e2e_fake.py

# Run end-to-end tests in CI mode (only fake PMs, no system impact)
[group('Testing')]
test-e2e-ci:
    #!/usr/bin/env bash
    echo "🤖 Running CI-safe end-to-end tests..."
    export PATH="./test:$PATH"
    export DOTFILES_PM_ONLY_FAKES="true"
    export DOTFILES_PM_DISABLE_REAL="true"  # Disable all real PMs for CI
    python3 test/test_e2e_fake.py



[private]
usage: default
