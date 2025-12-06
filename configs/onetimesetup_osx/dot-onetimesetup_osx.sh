#!/usr/bin/env bash
# Onetime setup tasks - macOS specific
#
# Prerequisites:
#   - Must source ~/.onetimesetup.sh first (provides infrastructure)
#   - macOS specific: defaults, ssh-add --apple-use-keychain
#
# Test hook for brother instances on macOS:
#   source ~/.onetimesetup.sh && source ~/.onetimesetup_osx.sh
#   LGREEN_ONETIMESETUP_DRYRUN=1 lgreen_onetimesetup_run_all

# =============================================================================
# macOS-Specific Tasks
# =============================================================================

lgreen_onetimesetup_macos_ssh_keychain() {
    _onetimesetup_log "==> macOS SSH Keychain Integration"

    local added_count=0
    local key

    for key in "$HOME"/.ssh/id_*; do
        # Skip public keys
        case "$key" in
            *.pub) continue ;;
        esac

        # Skip if not a file
        [ -f "$key" ] || continue

        if _onetimesetup_is_dryrun; then
            _onetimesetup_log "  DRYRUN: Would add $key to macOS Keychain"
            added_count=$((added_count + 1))
        else
            _onetimesetup_log "  Adding $(basename "$key") to macOS Keychain..."
            if ssh-add --apple-use-keychain "$key" 2>&1; then
                added_count=$((added_count + 1))
            else
                _onetimesetup_log "  ⚠ Failed to add $(basename "$key") (may need passphrase)"
            fi
        fi
    done

    if [ $added_count -gt 0 ]; then
        _onetimesetup_log "  ✓ Processed $added_count SSH keys"
    else
        _onetimesetup_log "  ⚠ No SSH keys found in ~/.ssh/"
    fi

    lgreen_onetimesetup_record_task "macos_ssh_keychain"
}

lgreen_onetimesetup_macos_finder() {
    _onetimesetup_log "==> macOS Finder Configuration"

    if _onetimesetup_is_dryrun; then
        _onetimesetup_log "  DRYRUN: Would run: defaults write com.apple.finder AppleShowAllFiles TRUE"
        _onetimesetup_log "  DRYRUN: Would run: killall Finder"
    else
        defaults write com.apple.finder AppleShowAllFiles TRUE
        killall Finder 2>/dev/null || true
    fi

    _onetimesetup_log "  ✓ Finder configured to show hidden files"
    lgreen_onetimesetup_record_task "macos_finder"
}

lgreen_onetimesetup_macos_scroll() {
    _onetimesetup_log "==> macOS Scroll Direction"

    if _onetimesetup_is_dryrun; then
        _onetimesetup_log "  DRYRUN: Would run: defaults write NSGlobalDomain com.apple.swipescrolldirection -bool false"
    else
        defaults write NSGlobalDomain com.apple.swipescrolldirection -bool false
    fi

    _onetimesetup_log "  ✓ Natural scrolling disabled"
    lgreen_onetimesetup_record_task "macos_scroll"
}

lgreen_onetimesetup_macos_minimap_font() {
    _onetimesetup_log "==> Installing Minimap Font"

    if ! command -v curl >/dev/null 2>&1; then
        _onetimesetup_log "  ⚠ curl not installed, skipping"
        return 0
    fi

    local font_dir="$HOME/Library/Fonts"
    local font_file="Minimap.ttf"
    local font_path="$font_dir/$font_file"

    if [ -f "$font_path" ]; then
        _onetimesetup_log "  ✓ Already installed: $font_path"
        return 0
    fi

    if _onetimesetup_is_dryrun; then
        _onetimesetup_log "  DRYRUN: Would create $font_dir"
        _onetimesetup_log "  DRYRUN: Would download to $font_path"
        lgreen_onetimesetup_record_task "macos_minimap_font"
        return 0
    fi

    _onetimesetup_log "  Creating fonts directory..."
    mkdir -p "$font_dir"

    _onetimesetup_log "  Downloading Minimap font..."
    if curl -fLo "$font_path" \
        "https://github.com/davestewart/minimap-font/raw/master/src/Minimap.ttf"; then

        _onetimesetup_log "  ✓ Minimap font installed: $font_path"
        lgreen_onetimesetup_record_task "macos_minimap_font"
    else
        _onetimesetup_log "  ✗ Download failed"
        return 1
    fi
}

lgreen_onetimesetup_macos_tcc_reset() {
    _onetimesetup_log "==> macOS TCC Database Reset (Accessibility)"
    _onetimesetup_log ""
    _onetimesetup_log "  ⚠️  WARNING: This is DESTRUCTIVE!"
    _onetimesetup_log "  ⚠️  Resets ALL Accessibility permissions"
    _onetimesetup_log "  ⚠️  You must manually re-grant permissions afterward"
    _onetimesetup_log ""
    _onetimesetup_log "  This function is kept in DRY-RUN mode for safety."
    _onetimesetup_log "  To run manually:"
    _onetimesetup_log "    tccutil reset Accessibility"
    _onetimesetup_log ""

    # ALWAYS force dry-run for safety - this is too destructive
    _onetimesetup_log "  DRYRUN: Would run: tccutil reset Accessibility"
    _onetimesetup_log "  ⚠️  Manual execution required for safety"

    lgreen_onetimesetup_record_task "macos_tcc_reset_info_shown"
}

# =============================================================================
# Platform Hook (called by common infrastructure)
# =============================================================================

lgreen_onetimesetup_run_platform() {
    _onetimesetup_log "Platform detected: macOS (Darwin)"
    _onetimesetup_log ""

    lgreen_onetimesetup_macos_ssh_keychain
    lgreen_onetimesetup_macos_finder
    lgreen_onetimesetup_macos_scroll
    lgreen_onetimesetup_macos_minimap_font

    # Note: TCC reset available as lgreen_onetimesetup_macos_tcc_reset
    # but not run automatically due to destructive nature
}
