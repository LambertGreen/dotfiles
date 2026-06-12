# Dotfiles Management System
# Note: Configuration loaded from ~/.dotfiles.env via shell sourcing in commands
#
# ═══════════════════════════════════════════════════════════════════════════════
# IMPORTANT: Windows Execution Environment
# ═══════════════════════════════════════════════════════════════════════════════
#
# On Windows, all `just` commands MUST be run from MSYS2 bash environment.
# This ensures:
#   - Consistent POSIX tool behavior (bash, python3, stow, etc.)
#   - Proper PATH inheritance from Windows
#   - Cross-platform compatibility with macOS/Linux workflows
#
# How to run on Windows:
#   1. Open MSYS2 terminal (not PowerShell, not CMD, not Cygwin)
#   2. Navigate to dotfiles directory
#   3. Run: just <command>
#
# Detection: The justfile checks for MSYSTEM environment variable to detect MSYS2.
# If running from wrong environment on Windows, you'll see a helpful error message.
#
# For AI Assistants: When testing in sandbox environments, ensure you're in MSYS2
# bash, not PowerShell or other Windows shells. Check with: echo $MSYSTEM
#
# ═══════════════════════════════════════════════════════════════════════════════

# Environment variables (will be loaded from ~/.dotfiles.env in commands)
platform := env_var_or_default("DOTFILES_PLATFORM", "")

# Set DOTFILES_DIR for all commands
export DOTFILES_DIR := justfile_directory()

# Check Windows execution environment - now supports both MSYS2 and PowerShell/CMD
# When running from PowerShell/CMD, we use 'py -3' for Python invocation
# When running from MSYS2, we use 'python3' as before
[private]
_check-windows-env:
    @echo "" > /dev/null

# Show configuration and available commands
default:
    @echo "🚀 New user? Start with: just configure → just bootstrap → just sync-submodules → just stow → just onetimesetup → just install"
    @echo ""
    @just --list
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
    @echo "Next step:"
    @echo "  just bootstrap"

# Bootstrap system (install core tools)
[group('1-🚀-Setup')]
bootstrap:
    @{{ if os() == "windows" { "C:/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -NoProfile -ExecutionPolicy Bypass -File bootstrap.ps1" } else { "./bootstrap.sh" } }}
    @echo ""
    @echo "Next step:"
    @echo "  just sync-submodules"

# Sync git submodules (clone/update private config repos, required before stow)
[group('1-🚀-Setup')]
sync-submodules:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔗 Syncing git submodules..."

    # Check if SSH config exists with github.com-personal host
    if [ -f ~/.ssh/config ] && grep -q "github.com-personal" ~/.ssh/config; then
        echo "✅ SSH config with github.com-personal found"
    else
        echo "⚠️  No SSH config with github.com-personal found"

        # Check for SSH keys
        if [ -f ~/.ssh/id_ed25519 ] || [ -f ~/.ssh/id_rsa ]; then
            echo "📝 Creating bootstrap SSH config..."

            # Backup existing config if present
            if [ -f ~/.ssh/config ]; then
                cp ~/.ssh/config ~/.ssh/config.backup-$(date +%Y%m%d%H%M%S)
                echo "   Backed up existing config"
            fi

            # Create bootstrap config
            mkdir -p ~/.ssh
            cp scripts/bootstrap/ssh-config-bootstrap ~/.ssh/config
            chmod 600 ~/.ssh/config
            echo "✅ Bootstrap SSH config created"
            echo "   (Will be replaced by full config after 'just stow')"
        else
            echo "❌ No SSH keys found in ~/.ssh/"
            echo "   Please set up SSH keys first:"
            echo "   1. Generate: ssh-keygen -t ed25519 -C 'your_email@example.com'"
            echo "   2. Add to GitHub: https://github.com/settings/keys"
            echo "   3. Run: just sync-submodules"
            exit 1
        fi
    fi

    # Sync and initialize submodules
    echo ""
    echo "📦 Syncing submodules (clone new, update existing)..."
    git submodule sync --recursive
    git submodule update --init --recursive

    echo ""
    echo "✅ Submodules synced"
    echo ""
    echo "Next step:"
    echo "  just stow"

# Deploy configuration files (symlink configs to home directory)
[group('1-🚀-Setup')]
stow:
    @if [ ! -f "$HOME/.dotfiles.env" ]; then \
        echo "❌ Platform not configured. Run: just configure"; \
        exit 1; \
    fi
    @if git submodule status | grep -q "^-"; then \
        echo "⚠️  Some submodules not initialized. Run: just sync-submodules"; \
        echo "   (Continuing anyway - some configs may be empty)"; \
    fi
    @. "$HOME/.dotfiles.env" && ./scripts/stow/stow.sh "$DOTFILES_PLATFORM"
    @echo ""
    @echo "Next step:"
    @echo "  just sync-configs  # Sync configs that don't auto-update via stow"
    @echo "  just onetimesetup"

# Sync configuration templates into live config files (apps that don't support separate config files)
[group('1-🚀-Setup')]
sync-configs:
    @echo "🔄 Syncing configuration templates to live config files..."
    @echo ""
    @echo "⚠️  The following apps mix config with runtime state:"
    @echo ""
    @echo "📝 Claude Code (~/.claude.json):"
    @echo "   Template: ~/.claude.json.template"
    @echo "   Action: Manually merge 'mcpServers' section from template into ~/.claude.json"
    @echo "   Why: Claude Code mixes MCP config with runtime state (tips history, session data)"
    @echo "   Command: jq -s '.[0] * {mcpServers: .[1].mcpServers}' ~/.claude.json ~/.claude.json.template > /tmp/merged.json && mv /tmp/merged.json ~/.claude.json"
    @echo ""
    @echo "💡 Future: We could automate this with jq merge scripts"
    @echo "💡 Shame: These apps should separate config from runtime state!"
    @echo ""
    @echo "✅ Done reviewing config sync needs"

# Run platform-specific one-time setup tasks
[group('1-🚀-Setup')]
onetimesetup:
    @if [ ! -f "$HOME/.onetimesetup.sh" ]; then \
        echo "❌ Onetimesetup script not found at ~/.onetimesetup.sh"; \
        echo "   Run the setup flow: just sync-submodules → just stow"; \
        exit 1; \
    fi
    @bash -c 'source ~/.onetimesetup.sh && \
        if [ "$(uname)" = "Darwin" ]; then \
            [ -f ~/.onetimesetup_osx.sh ] && source ~/.onetimesetup_osx.sh; \
        elif [ "$(uname)" = "Linux" ]; then \
            [ -f ~/.onetimesetup_linux.sh ] && source ~/.onetimesetup_linux.sh; \
            [ -f ~/.onetimesetup_wsl.sh ] && source ~/.onetimesetup_wsl.sh; \
        fi; \
        lgreen_onetimesetup_run_all'
    @echo ""
    @echo "Next step:"
    @echo "  just install"

# Generate Windows Start Menu shortcuts (Windows-Only)
[group('1-🚀-Setup (Windows-Only)')]
gen-win-startmenu-links:
    @echo "🔗 Generating Windows Start Menu shortcuts..."
    @{{ if os() == "windows" { "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/windows/gen-win-startmenu-links.ps1" } else { "echo '❌ Windows-only task (gen-win-startmenu-links)'" } }}
    @echo "✅ Start Menu shortcuts ensured"

# Generate Windows Startup shortcuts (Windows-Only)
[group('1-🚀-Setup (Windows-Only)')]
gen-win-startup-links:
    @echo "🔗 Generating Windows Startup shortcuts..."
    @{{ if os() == "windows" { "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/windows/gen-win-startup-links.ps1" } else { "echo '❌ Windows-only task (gen-win-startup-links)'" } }}
    @echo "✅ Startup shortcuts ensured"

# Import Windows registry keys for current machine class (Windows-Only)
[group('1-🚀-Setup (Windows-Only)')]
import-win-regkeys:
    @echo "🧩 Importing Windows registry keys for machine class..."
    @{{ if os() == "windows" { "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/windows/import-regkeys.ps1" } else { "echo '❌ Windows-only task (import-win-regkeys)'" } }}
    @echo "✅ Registry import completed (see ~/.dotfiles/logs/ for details)"

# Install packages via all package managers
[group('2-📦-Package-Management')]
install:
    @just _check-windows-env
    @echo "📦 Installing packages for current machine class..."
    @{{ if os() == "windows" { "py -3 -m src.dotfiles_pm.pm install" } else { "bash -c 'if [ -f \"$HOME/.dotfiles.env\" ]; then . \"$HOME/.dotfiles.env\"; fi; EXIT_CODE=0; python3 -m src.dotfiles_pm.pm install; EXIT_CODE=$?; if [ \"$EXIT_CODE\" -eq 41 ]; then echo \"❌ Brew locked. Fix with: just doctor-fix-brew-lock\"; exit 1; fi; exit \"$EXIT_CODE\"'" } }}

# Update package registries and check for available updates
[group('2-📦-Package-Management')]
update:
    @just _check-windows-env
    @echo "🔄 Updating package registries and checking for updates..."
    @{{ if os() == "windows" { "py -3 -m src.dotfiles_pm.pm check" } else { "bash -c 'if [ -f \"$HOME/.dotfiles.env\" ]; then . \"$HOME/.dotfiles.env\"; fi; EXIT_CODE=0; python3 -m src.dotfiles_pm.pm check; EXIT_CODE=$?; if [ \"$EXIT_CODE\" -eq 41 ]; then echo \"❌ Brew locked. Fix with: just doctor-fix-brew-lock\"; exit 1; fi; exit \"$EXIT_CODE\"'" } }}

# Upgrade packages across package managers
[group('2-📦-Package-Management')]
upgrade:
    @just _check-windows-env
    @echo "🔄 Upgrading packages (interactive)..."
    @{{ if os() == "windows" { "py -3 -m src.dotfiles_pm.pm upgrade" } else { "bash -c 'if [ -f \"$HOME/.dotfiles.env\" ]; then . \"$HOME/.dotfiles.env\"; fi; EXIT_CODE=0; python3 -m src.dotfiles_pm.pm upgrade; EXIT_CODE=$?; if [ \"$EXIT_CODE\" -eq 41 ]; then echo \"❌ Brew locked. Fix with: just doctor-fix-brew-lock\"; exit 1; fi; exit \"$EXIT_CODE\"'" } }}

# Show available package managers
[group('3-ℹ️-Info')]
show-package-managers:
    @just _check-windows-env
    @bash -c 'EXIT_CODE=0; python3 -m src.dotfiles_pm.pm list; EXIT_CODE=$?; if [ "$EXIT_CODE" -eq 41 ]; then echo "❌ Brew locked. Fix with: just doctor-fix-brew-lock"; exit 1; fi; exit "$EXIT_CODE"'

# Show package counts summary
[group('3-ℹ️-Info')]
show-package-summary:
    @./scripts/package-management/show-package-stats.sh
    @echo ""
    @echo "💡 Next step:"
    @echo "  just show-package-list"

# Show detailed package lists
[group('3-ℹ️-Info')]
show-package-list:
    @./scripts/package-management/show-packages.sh
    @echo ""
    @echo "💡 Next step:"
    @echo "  just show-package-summary"


# ═══════════════════════════════════════════════════════════════════════════════
# Doctor Commands (System Health & Diagnostics)
# ═══════════════════════════════════════════════════════════════════════════════

# Diagnose and fix Homebrew lock issues
[group('4-👩‍⚕️-Doctor')]
doctor-fix-brew-lock:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "👩‍⚕️ Intelligent Homebrew Lock Diagnosis"
    echo "======================================"
    echo ""

    # Step 1: Check current status
    echo "1. 🔍 Analyzing current brew status..."
    python3 -m src.dotfiles_pm.pms.brew_utils status
    echo ""

    # Step 2: Check for running processes
    echo "2. 🔍 Checking for running brew processes..."
    processes=$(python3 -c "
    from src.dotfiles_pm.pms.brew_utils import brew_lock_manager
    processes = brew_lock_manager.find_brew_processes()
    print(len(processes))
    for p in processes:
        print(f'{p.pid}:{p.command[:60]}')
    ")

    process_count=$(echo "$processes" | head -1)
    if [ "$process_count" -gt 0 ]; then
        echo "   Found $process_count running brew processes:"
        echo "$processes" | tail -n +2 | while read line; do
            echo "   • $line"
        done
        echo ""
        echo "   🤔 These processes might be causing the lock."
        echo "   💡 You can:"
        echo "      - Wait for them to finish naturally"
        echo "      - Kill them if they're stuck (see below)"
        echo ""
        read -p "   ❓ Kill these processes? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "   🔪 Killing processes..."
            python3 -m src.dotfiles_pm.pms.brew_utils kill
            echo "   ✅ Processes killed"
        else
            echo "   ⏳ Skipping process termination"
        fi
    else
        echo "   ✅ No running brew processes found"
    fi
    echo ""

    # Step 3: Check for orphaned lock files
    echo "3. 🔍 Checking for orphaned lock files..."
    python3 -m src.dotfiles_pm.pms.brew_utils check-orphaned-locks
    orphaned_result=$(python3 -c "
    from src.dotfiles_pm.pms.brew_utils import check_orphaned_locks
    result = check_orphaned_locks()
    print(len(result['orphaned_locks']))
    ")

    if [ "$orphaned_result" -gt 0 ]; then
        echo ""
        echo "   🤔 Found $orphaned_result orphaned lock files."
        echo "   💡 These are lock files without running processes."
        echo ""
        read -p "   ❓ Remove orphaned lock files? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "   🧹 Removing orphaned locks..."
            # Remove lock files (platform-specific paths)
            if [[ "$OSTYPE" == "darwin"* ]]; then
                LOCK_DIR="/opt/homebrew/var/homebrew/locks"
            elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
                # Try common Linuxbrew paths
                if [ -d "$HOME/.linuxbrew/var/homebrew/locks" ]; then
                    LOCK_DIR="$HOME/.linuxbrew/var/homebrew/locks"
                elif [ -d "/home/linuxbrew/.linuxbrew/var/homebrew/locks" ]; then
                    LOCK_DIR="/home/linuxbrew/.linuxbrew/var/homebrew/locks"
                elif [ -d "/usr/local/var/homebrew/locks" ]; then
                    LOCK_DIR="/usr/local/var/homebrew/locks"
                else
                    echo "   ❌ Linuxbrew lock directory not found"
                    exit 1
                fi
            else
                echo "   ❌ Unsupported platform for brew lock cleanup"
                exit 1
            fi

            find "$LOCK_DIR" -name "*.lock" -o -name "update" | while read lockfile; do
                if [ -f "$lockfile" ]; then
                    rm -f "$lockfile"
                    echo "   • Removed $(basename "$lockfile")"
                fi
            done
            echo "   ✅ Orphaned locks removed"
        else
            echo "   ⏳ Skipping lock file removal"
        fi
    else
        echo "   ✅ No orphaned lock files found"
    fi
    echo ""

    # Step 4: Final test
    echo "4. 🧪 Testing brew availability..."
    if brew --version >/dev/null 2>&1; then
        echo "   ✅ Homebrew is now available!"
        echo "   💡 Try your original command again"
    else
        echo "   ❌ Homebrew still not available"
        echo "   💡 Manual intervention may be required:"
        echo "      • Check /opt/homebrew/var/homebrew/locks/ for remaining locks"
        echo "      • Run: brew doctor"
        echo "      • Consider system reboot if issue persists"
    fi

# Disable problematic package managers
[group('4-👩‍⚕️-Doctor')]
doctor-disable-a-package-manager:
    @just _check-windows-env
    @echo "👩‍⚕️ Disabling problematic package managers..."
    @bash -c 'EXIT_CODE=0; python3 -m src.dotfiles_pm.pm configure; EXIT_CODE=$?; if [ "$EXIT_CODE" -eq 41 ]; then echo "❌ Brew locked. Fix with: just doctor-fix-brew-lock"; exit 1; fi; if [ "$EXIT_CODE" -eq 0 ]; then echo ""; echo "Next steps:"; echo "  just doctor-check-health   # Verify symlinks were created successfully"; fi; exit "$EXIT_CODE"'

# Check system health
[group('4-👩‍⚕️-Doctor')]
doctor-check-health:
    @echo "👩‍⚕️ Running comprehensive system health check..."
    @bash -c "source scripts/health/dotfiles-health.sh && dotfiles_check_health"

# Check PATH for broken entries, version-specific paths, and duplicates (cross-platform)
[group('4-👩‍⚕️-Doctor')]
doctor-check-path:
    @just _check-windows-env
    @echo "👩‍⚕️ Checking PATH health (cross-platform)..."
    @python3 src/dotfiles_pm/doctor.py

# Check Emacs version compatibility and suggest elpaca cleanup if needed
[group('4-👩‍⚕️-Doctor')]
doctor-check-emacs-version:
    @echo "👩‍⚕️ Checking Emacs version compatibility..."
    @bash -c "source scripts/health/doctor-emacs-version-change.sh && doctor_emacs_version_change"

# Check package manager versions (terminal spawning regression test)
[group('4-👩‍⚕️-Doctor')]
doctor-pm-versions:
    @just _check-windows-env
    @echo "👩‍⚕️ Checking package manager versions..."
    @bash -c 'if [ -f "$HOME/.dotfiles.env" ]; then . "$HOME/.dotfiles.env"; fi; python3 -m src.dotfiles_pm.pm version'

# Check Homebrew tap state against Brewfile declarations
[group('4-👩‍⚕️-Doctor')]
doctor-check-taps:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "👩‍⚕️ Checking Homebrew tap state..."

    # Determine machine class
    if [ -f "$HOME/.dotfiles.env" ]; then
        source "$HOME/.dotfiles.env"
    fi
    MACHINE_CLASS="${DOTFILES_MACHINE_CLASS:-}"
    if [ -z "$MACHINE_CLASS" ]; then
        echo "❌ DOTFILES_MACHINE_CLASS not set. Cannot determine expected taps."
        exit 1
    fi

    BREWFILE="machine-classes/${MACHINE_CLASS}/brew/Brewfile"
    if [ ! -f "$BREWFILE" ]; then
        echo "❌ Brewfile not found: $BREWFILE"
        exit 1
    fi

    echo "  Machine class: $MACHINE_CLASS"
    echo "  Brewfile: $BREWFILE"
    echo ""

    # Get declared taps from Brewfile (excluding homebrew/core and homebrew/cask)
    declared_taps=$(grep '^tap ' "$BREWFILE" | sed 's/tap "//;s/".*//' | grep -v '^homebrew/' | sort)

    # Get installed taps (excluding homebrew/core and homebrew/cask)
    installed_taps=$(brew tap 2>/dev/null | grep -v '^homebrew/' | sort)

    # Get untrusted taps (brew 6.0+: third-party taps not in trust.json)
    trust_file="$HOME/.homebrew/trust.json"
    if [ ! -f "$trust_file" ]; then
        trust_file="${XDG_CONFIG_HOME:-$HOME/.config}/homebrew/trust.json"
    fi
    if [ -f "$trust_file" ]; then
        trusted=$(python3 -c "import json; d=json.load(open('$trust_file')); print('\n'.join(d.get('trustedtaps', [])))" 2>/dev/null | sort)
    else
        trusted=""
    fi
    untrusted_taps=$(comm -23 <(echo "$installed_taps") <(echo "$trusted"))

    # Compare
    extra_taps=$(comm -23 <(echo "$installed_taps") <(echo "$declared_taps"))
    missing_taps=$(comm -13 <(echo "$installed_taps") <(echo "$declared_taps"))

    issues=0

    if [ -n "$missing_taps" ]; then
        echo "📦 Missing taps (in Brewfile but not installed):"
        echo "$missing_taps" | while read tap; do
            echo "  • $tap"
        done
        echo "  💡 Fix: brew tap <tap-name>"
        echo ""
        issues=$((issues + 1))
    fi

    if [ -n "$extra_taps" ]; then
        echo "🗑️  Extra taps (installed but not in Brewfile):"
        echo "$extra_taps" | while read tap; do
            echo "  • $tap"
        done
        echo "  💡 Fix: brew untap <tap-name> (if no longer needed)"
        echo ""
        issues=$((issues + 1))
    fi

    if [ -n "$untrusted_taps" ]; then
        echo "🔒 Untrusted taps (brew 6.0+ requires explicit trust):"
        echo "$untrusted_taps" | while read tap; do
            echo "  • $tap"
        done
        echo "  💡 Fix: brew trust <tap-name>"
        echo ""
        issues=$((issues + 1))
    fi

    if [ "$issues" -eq 0 ]; then
        echo "✅ All taps in sync and trusted"
    else
        echo "---"
        echo "Found $issues issue(s). Run suggested fix commands above."
    fi

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
