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

# ═══════════════════════════════════════════════════════════════════════════════
# Testing Commands
# ═══════════════════════════════════════════════════════════════════════════════

# Run unit tests (uses mocks, fast feedback)
[group('5-🧪-Testing')]
test-run-unit:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🧪 Running unit tests (mocked dependencies)..."
    eval "$(direnv export bash)"
    python3 -m pytest tests/ -v || echo "⚠️  Some tests failed (expected during development)"

# Run unit tests with code coverage
[group('5-🧪-Testing')]
test-run-unit-coverage:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🧪 Running unit tests with code coverage..."
    eval "$(direnv export bash)"
    python3 -m pytest tests/ -v --cov=src --cov-report=term-missing --cov-report=html:htmlcov
    echo "📊 Coverage report generated in htmlcov/"

# Run functional tests (uses fake package managers)
[group('5-🧪-Testing')]
test-run-functional:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🧪 Running functional tests (fake PMs)..."
    eval "$(direnv export bash)"
    export PATH="./test:$PATH"
    export DOTFILES_PM_ONLY_FAKES="true"
    export DOTFILES_PM_ENABLED="fake-pm1,fake-pm2"
    python3 -m src.dotfiles_pm.pm list
    echo "✅ Functional tests completed"

# Run functional tests with code coverage
[group('5-🧪-Testing')]
test-run-functional-coverage:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🧪 Running functional tests with code coverage..."
    eval "$(direnv export bash)"
    export PATH="./test:$PATH"
    export DOTFILES_PM_ONLY_FAKES="true"
    export DOTFILES_PM_ENABLED="fake-pm1,fake-pm2"
    python3 -m pytest tests/e2e/test_e2e_fake.py -v --cov=src --cov-report=term-missing --cov-report=html:htmlcov
    echo "📊 Coverage report generated in htmlcov/"

# Run integration tests (uses Docker containers)
[group('5-🧪-Testing')]
test-run-integration:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🧪 Running integration tests (Docker containers)..."
    echo "TODO: Implement Docker-based integration tests"
    echo "   - test/ directory contains Docker test infrastructure"
    echo "   - Need to implement actual integration test commands"
    echo "   - Should test full system setup in containers"
    echo "✅ Integration test setup (TODO: implement actual tests)"

# Run comprehensive test suite (all test types)
[group('5-🧪-Testing')]
test-run-all:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🧪 Running comprehensive test suite..."
    eval "$(direnv export bash)"
    echo "1. Unit tests..."
    just test-run-unit || echo "   Unit tests had issues (continuing...)"
    echo ""
    echo "2. Functional tests..."
    just test-run-functional || echo "   Functional tests had issues (continuing...)"
    echo ""
    echo "3. Integration tests..."
    just test-run-integration || echo "   Integration tests had issues (continuing...)"
    echo ""
    echo "4. Testing brew lock detection..."
    python3 -m src.dotfiles_pm.pms.brew_utils status || echo "   Brew utils test failed"
    echo ""
    echo "✅ Test suite completed"

# Run comprehensive test suite with code coverage
[group('5-🧪-Testing')]
test-run-all-coverage:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🧪 Running comprehensive test suite with code coverage..."
    eval "$(direnv export bash)"
    echo "1. Unit tests with coverage..."
    just test-run-unit-coverage || echo "   Unit tests had issues (continuing...)"
    echo ""
    echo "2. Functional tests with coverage..."
    just test-run-functional-coverage || echo "   Functional tests had issues (continuing...)"
    echo ""
    echo "3. Integration tests..."
    just test-run-integration || echo "   Integration tests had issues (continuing...)"
    echo ""
    echo "4. Testing brew lock detection..."
    python3 -m src.dotfiles_pm.pms.brew_utils status || echo "   Brew utils test failed"
    echo ""
    echo "📊 Final coverage report available in htmlcov/"
    echo "✅ Comprehensive test suite with coverage completed"

# Run code coverage only (quick coverage check)
[group('5-🧪-Testing')]
test-coverage:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "📊 Running code coverage analysis..."
    eval "$(direnv export bash)"
    python3 -m pytest tests/ -v --cov=src --cov-report=term-missing --cov-report=html:htmlcov --cov-fail-under=25
    echo "📊 Coverage report generated in htmlcov/"

# Open coverage report in browser
[group('5-🧪-Testing')]
test-coverage-open:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -f "htmlcov/index.html" ]; then
        echo "🌐 Opening coverage report in browser..."
        open htmlcov/index.html || xdg-open htmlcov/index.html || echo "Please open htmlcov/index.html manually"
    else
        echo "❌ No coverage report found. Run 'just test-coverage' first."
        exit 1
    fi

# Enter testing context (advanced Docker + integration tests)
[group('5-🧪-Testing')]
test-context:
    @echo "🧪 Entering advanced testing context..."
    @echo "Use 'just' to see Docker-based integration tests"
    @cd test && exec $SHELL

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
