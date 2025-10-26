# Emacs Version Change Doctor
# Detects Emacs version changes and suggests elpaca cleanup
#
# Usage:
#   source doctor-emacs-version-change.sh
#   doctor_emacs_version_change

# Check if Emacs version changed and elpaca needs cleanup
doctor_emacs_version_change() {
    echo "🔍 Checking Emacs version compatibility..."

    # Get current Emacs version
    if ! command -v emacs &>/dev/null; then
        echo "❌ Emacs not found in PATH"
        return 1
    fi

    local current_version
    current_version=$(emacs --version | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
    echo "📦 Current Emacs version: $current_version"

    # Check elpaca directories for version mismatches
    local emacs_d="${HOME}/.emacs.d"
    local elpaca_dir="${emacs_d}/elpaca"
    local eln_cache_dir="${emacs_d}/eln-cache"

    if [[ ! -d "$elpaca_dir" ]]; then
        echo "✅ No elpaca directory found - fresh install or already cleaned"
        return 0
    fi

    # Get eln-cache versions
    if [[ -d "$eln_cache_dir" ]]; then
        local eln_versions
        eln_versions=$(ls -1 "$eln_cache_dir" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+' || true)

        # Check if current version has eln-cache
        local current_eln_exists=false
        while IFS= read -r eln_ver; do
            if [[ "$eln_ver" =~ ^${current_version} ]]; then
                current_eln_exists=true
                echo "✅ Found eln-cache for current version: $eln_ver"
            fi
        done <<< "$eln_versions"

        # Check for old versions
        local old_versions
        old_versions=$(echo "$eln_versions" | grep -v "^${current_version}" || true)

        if [[ -n "$old_versions" && "$current_eln_exists" == "true" ]]; then
            echo ""
            echo "⚠️  Found eln-cache for multiple Emacs versions:"
            echo "$eln_versions" | sed 's/^/    /'
            echo ""
            echo "💡 Old eln-cache directories can be safely deleted:"
            echo "    rm -rf ~/.emacs.d/eln-cache/<old-version>"
        fi

        # Check if no eln-cache for current version but elpaca exists
        if [[ "$current_eln_exists" == "false" && -d "$elpaca_dir" ]]; then
            echo ""
            echo "⚠️  WARNING: Emacs version changed but packages not rebuilt!"
            echo ""
            echo "Current version: $current_version"
            echo "Existing eln-cache versions:"
            echo "$eln_versions" | sed 's/^/    /'
            echo ""
            echo "🔧 RECOMMENDED ACTION: Rebuild elpaca for new Emacs version"
            echo ""
            echo "Steps:"
            echo "  1. Quit Emacs if running"
            echo "  2. Delete elpaca directory:"
            echo "     rm -rf ~/.emacs.d/elpaca"
            echo "  3. Restart Emacs (it will reinstall and recompile all packages)"
            echo ""
            return 1
        fi
    fi

    # Check brew logs for recent emacs installation
    local brew_log_dir="${HOME}/.dotfiles/logs"
    if [[ -d "$brew_log_dir" ]]; then
        local recent_brew_log
        recent_brew_log=$(find "$brew_log_dir" -name "brew-install-*.log" -mtime -1 2>/dev/null | sort -r | head -1)

        if [[ -n "$recent_brew_log" ]]; then
            if grep -q "Installing.*emacs-mac" "$recent_brew_log" 2>/dev/null; then
                echo ""
                echo "📋 Recent brew log shows Emacs installation:"
                echo "   $recent_brew_log"
                grep "Installing.*emacs-mac" "$recent_brew_log" | sed 's/^/   /'
                echo ""
                echo "💡 If you experience 'Symbol's value as variable is void' errors,"
                echo "   delete ~/.emacs.d/elpaca and restart Emacs"
            fi
        fi
    fi

    echo ""
    echo "✅ Emacs version check complete"
    return 0
}
