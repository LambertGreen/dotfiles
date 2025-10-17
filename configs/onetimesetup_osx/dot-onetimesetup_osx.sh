#!/usr/bin/env sh
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

# =============================================================================
# Platform Hook (called by common infrastructure)
# =============================================================================

lgreen_onetimesetup_run_platform() {
    _onetimesetup_log "Platform detected: macOS (Darwin)"
    _onetimesetup_log ""

    lgreen_onetimesetup_macos_ssh_keychain
    lgreen_onetimesetup_macos_finder
    lgreen_onetimesetup_macos_scroll
}
