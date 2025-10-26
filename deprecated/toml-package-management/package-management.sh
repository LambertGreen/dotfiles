#!/usr/bin/env bash
# Package Management Tool - Main Entry Point
# Delegates to the TOML-based installer in scripts/

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Delegate to the actual installer
exec "$SCRIPT_DIR/scripts/install.sh" "$@"