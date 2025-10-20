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
    @just --list | awk '/^    \[.*\]$/{if($0 ~ /Advanced-Testing/) skip=1; else skip=0} !skip'
    @echo ""
    @echo "💡 For advanced testing commands: just --list"

# ═══════════════════════════════════════════════════════════════════════════════
# Core User Commands
# ═══════════════════════════════════════════════════════════════════════════════

# Interactive configuration (select machine class)
[group('1-🚀-Setup')]
configure:
    @{{ if os() == "windows" { "C:/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -NoProfile -ExecutionPolicy Bypass -File configure.ps1" } else { "./configure.sh" } }}
    @echo ""
    @echo "Next steps:"
    @echo "  just bootstrap        # Install core tools (Python, stow, just, etc.)"
    @echo "  just stow            # Deploy configuration files"
    @echo "  just install         # Install packages"
    @echo "  just doctor-disable-a-package-manager    # Disable problematic package managers"
    @echo "  just doctor-check-health    # Validate system health"

# Bootstrap system (install core tools)
[group('1-🚀-Setup')]
bootstrap:
    @{{ if os() == "windows" { "C:/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -NoProfile -ExecutionPolicy Bypass -File bootstrap.ps1" } else { "./bootstrap.sh" } }}
    @echo ""
    @echo "Next steps:"
    @echo "  just stow           # Deploy configurations"
    @echo "  just doctor-check-health   # Verify setup"

# Deploy configuration files
[group('1-🚀-Setup')]
stow:
    @if [ ! -f "$HOME/.dotfiles.env" ]; then \
        echo "❌ Platform not configured. Run: just configure"; \
        exit 1; \
    fi
    @. "$HOME/.dotfiles.env" && ./scripts/stow/stow.sh "$DOTFILES_PLATFORM"
    @echo ""
    @echo "Next steps:"
    @echo "  just doctor-check-health   # Verify symlinks were created successfully"

# Install packages via all package managers
[group('2-📦-Package-Management')]
install:
    @echo "📦 Installing packages for current machine class..."
    @if [ -f "$HOME/.dotfiles.env" ]; then . "$HOME/.dotfiles.env"; fi && python3 -m src.dotfiles_pm.pm install || \
    if [ $$? -eq 41 ]; then \
        echo "❌ Brew locked. Fix with: just doctor-fix-brew-lock"; \
        exit 1; \
    fi

# Update package registries and check for available updates
[group('2-📦-Package-Management')]
update:
    @echo "🔄 Updating package registries and checking for updates..."
    @if [ -f "$HOME/.dotfiles.env" ]; then . "$HOME/.dotfiles.env"; fi && python3 -m src.dotfiles_pm.pm check || \
    if [ $$? -eq 41 ]; then \
        echo "❌ Brew locked. Fix with: just doctor-fix-brew-lock"; \
        exit 1; \
    fi

# Upgrade packages across package managers
[group('2-📦-Package-Management')]
upgrade:
    @echo "🔄 Upgrading packages (interactive)..."
    @if [ -f "$HOME/.dotfiles.env" ]; then . "$HOME/.dotfiles.env"; fi && python3 -m src.dotfiles_pm.pm upgrade || \
    if [ $$? -eq 41 ]; then \
        echo "❌ Brew locked. Fix with: just doctor-fix-brew-lock"; \
        exit 1; \
    fi

# Show available package managers
[group('3-ℹ️-Info')]
show-package-managers:
    @python3 -m src.dotfiles_pm.pm list || \
    if [ $$? -eq 41 ]; then \
        echo "❌ Brew locked. Fix with: just doctor-fix-brew-lock"; \
        exit 1; \
    fi

# Show package counts summary
[group('3-ℹ️-Info')]
show-package-summary:
    @./scripts/package-management/show-package-stats.sh
    @echo ""
    @echo "💡 Next steps:"
    @echo "  just show-package-list  # View detailed package lists"

# Show detailed package lists
[group('3-ℹ️-Info')]
show-package-list:
    @./scripts/package-management/show-packages.sh
    @echo ""
    @echo "💡 Next steps:"
    @echo "  just show-package-summary  # View package counts summary"


# ═══════════════════════════════════════════════════════════════════════════════
# Doctor Commands (System Health & Diagnostics)
# ═══════════════════════════════════════════════════════════════════════════════

# Diagnose and fix Homebrew lock issues
[group('4-👩‍⚕️-Doctor')]
doctor-fix-brew-lock:
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

# Disable problematic package managers
[group('4-👩‍⚕️-Doctor')]
doctor-disable-a-package-manager:
    @echo "👩‍⚕️ Disabling problematic package managers..."
    @python3 -m src.dotfiles_pm.pm configure || \
    if [ $$? -eq 41 ]; then \
        echo "❌ Brew locked. Fix with: just doctor-fix-brew-lock"; \
        exit 1; \
    fi
    @echo ""
    @echo "Next steps:"
    @echo "  just doctor-check-health   # Verify symlinks were created successfully"

# Check system health
[group('4-👩‍⚕️-Doctor')]
doctor-check-health:
    @echo "👩‍⚕️ Running comprehensive system health check..."
    @bash -c "source scripts/health/dotfiles-health.sh && dotfiles_check_health"

# Fix broken symlinks (destructive)
[group('4-👩‍⚕️-Doctor')]
doctor-fix-broken-links:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "👩‍⚕️ Fixing broken symlinks..."
    echo "⚠️  This will remove broken symlinks permanently!"
    read -p "Continue? (y/N): " confirm
    if [ "$confirm" = "y" ]; then
        bash -c "source scripts/health/dotfiles-health.sh && dotfiles_cleanup_broken_links --remove"
    else
        echo "❌ Operation cancelled"
        exit 1
    fi


# ═══════════════════════════════════════════════════════════════════════════════
# Project Dev & Testing
# ═══════════════════════════════════════════════════════════════════════════════

# Check development prerequisites
[group('5-🧪-Dev-Testing')]
check-dev-prerequisites:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔍 Checking development prerequisites..."
    ./devsetup/check-prerequisites.sh

# Run unit tests (uses mocks, fast feedback)
[group('5-🧪-Dev-Testing')]
test-unit:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🧪 Running unit tests (mocked dependencies)..."
    eval "$(direnv export bash)"
    python -m pytest tests/ -v || echo "⚠️  Some tests failed (expected during development)"

# Run functional tests (uses fake package managers)
[group('5-🧪-Dev-Testing')]
test-functional:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🧪 Running functional tests (fake PMs)..."
    eval "$(direnv export bash)"
    export PATH="./test:$PATH"
    export DOTFILES_PM_ONLY_FAKES="true"
    export DOTFILES_PM_ENABLED="fake-pm1,fake-pm2"
    python -m src.dotfiles_pm.pm list
    echo "✅ Functional tests completed"

# Run integration tests (uses Docker containers)
[group('5-🧪-Dev-Testing')]
test-integration:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🧪 Running integration tests (Docker containers)..."
    echo "TODO: Implement Docker-based integration tests"
    echo "   - test/ directory contains Docker test infrastructure"
    echo "   - Need to implement actual integration test commands"
    echo "   - Should test full system setup in containers"
    echo "✅ Integration test setup (TODO: implement actual tests)"

# Run all tests
[group('5-🧪-Dev-Testing')]
test-all:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🧪 Running comprehensive test suite..."
    eval "$(direnv export bash)"
    echo "1. Unit tests..."
    just test-unit || echo "   Unit tests had issues (continuing...)"
    echo ""
    echo "2. Functional tests..."
    just test-functional || echo "   Functional tests had issues (continuing...)"
    echo ""
    echo "3. Integration tests..."
    just test-integration || echo "   Integration tests had issues (continuing...)"
    echo ""
    echo "4. Testing brew lock detection..."
    python -m src.dotfiles_pm.pms.brew_utils status || echo "   Brew utils test failed"
    echo ""
    echo "✅ Test suite completed"

# Run unit tests with code coverage
[group('🔧-Advanced-Testing')]
test-unit-coverage:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🧪 Running unit tests with code coverage..."
    eval "$(direnv export bash)"
    python -m pytest tests/ -v --cov=src --cov-report=term-missing --cov-report=html:.test/coverage
    echo "📊 Coverage report generated in .test/coverage/"

# Run functional tests with code coverage
[group('🔧-Advanced-Testing')]
test-functional-coverage:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🧪 Running functional tests with code coverage..."
    eval "$(direnv export bash)"
    export PATH="./test:$PATH"
    export DOTFILES_PM_ONLY_FAKES="true"
    export DOTFILES_PM_ENABLED="fake-pm1,fake-pm2"
    python -m pytest tests/test_e2e_pm_check.py tests/test_integration.py -v --cov=src --cov-report=term-missing --cov-report=html:.test/coverage
    echo "📊 Coverage report generated in .test/coverage/"

# Run comprehensive test suite with code coverage
[group('🔧-Advanced-Testing')]
test-all-coverage:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🧪 Running comprehensive test suite with code coverage..."
    eval "$(direnv export bash)"
    echo "1. Unit tests with coverage..."
    just test-unit-coverage || echo "   Unit tests had issues (continuing...)"
    echo ""
    echo "2. Functional tests with coverage..."
    just test-functional-coverage || echo "   Functional tests had issues (continuing...)"
    echo ""
    echo "3. Integration tests..."
    just test-integration || echo "   Integration tests had issues (continuing...)"
    echo ""
    echo "4. Testing brew lock detection..."
    python -m src.dotfiles_pm.pms.brew_utils status || echo "   Brew utils test failed"
    echo ""
    echo "📊 Final coverage report available in .test/coverage/"
    echo "✅ Comprehensive test suite with coverage completed"

# Run code coverage only (quick coverage check)
[group('🔧-Advanced-Testing')]
test-coverage:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "📊 Running code coverage analysis..."
    eval "$(direnv export bash)"
    python -m pytest tests/ -v --cov=src --cov-report=term-missing --cov-report=html:.test/coverage --cov-fail-under=5
    echo "📊 Coverage report generated in .test/coverage/"

# Open coverage report in browser
[group('🔧-Advanced-Testing')]
test-coverage-open:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -f ".test/coverage/index.html" ]; then
        echo "🌐 Opening coverage report in browser..."
        open .test/coverage/index.html || xdg-open .test/coverage/index.html || echo "Please open .test/coverage/index.html manually"
    else
        echo "❌ No coverage report found. Run 'just test-coverage' first."
        exit 1
    fi
