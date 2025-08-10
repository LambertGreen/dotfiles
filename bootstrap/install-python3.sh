#!/usr/bin/env bash
# Platform-agnostic Python 3.11+ installer
# Ensures Python with native tomllib support is available

set -euo pipefail

# Check Python version
check_python_version() {
    if command -v python3 >/dev/null 2>&1; then
        python3 -c 'import sys; exit(0 if sys.version_info >= (3, 11) else 1)' 2>/dev/null
        return $?
    fi
    return 1
}

# Detect platform
detect_platform() {
    case "$(uname -s)" in
        Darwin*) echo "osx" ;;
        Linux*)
            if [ -f /etc/arch-release ]; then
                echo "arch"
            elif [ -f /etc/debian_version ]; then
                echo "ubuntu"
            else
                echo "unknown"
            fi
            ;;
        MINGW*|MSYS*|CYGWIN*) echo "win" ;;
        *) echo "unknown" ;;
    esac
}

# Main logic
main() {
    echo "🐍 Checking Python 3.11+ (native tomllib support)..."
    
    if check_python_version; then
        PYTHON_VERSION=$(python3 --version 2>&1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+')
        echo "✅ Python $PYTHON_VERSION already installed with native tomllib"
        exit 0
    fi
    
    # Delegate to platform-specific installer
    PLATFORM=$(detect_platform)
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PLATFORM_SCRIPT="$SCRIPT_DIR/install-python3-${PLATFORM}.sh"
    
    if [ -f "$PLATFORM_SCRIPT" ]; then
        echo "📦 Delegating to platform installer: $(basename "$PLATFORM_SCRIPT")"
        exec "$PLATFORM_SCRIPT"
    else
        echo "❌ No installer found for platform: $PLATFORM"
        echo "💡 Please install Python 3.11+ manually"
        exit 1
    fi
}

main "$@"