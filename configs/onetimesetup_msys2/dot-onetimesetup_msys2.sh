#!/usr/bin/env sh
# Onetime setup tasks - MSYS2 specific
#
# Prerequisites:
#   - Must source ~/.onetimesetup.sh first (provides infrastructure)
#   - MSYS2 environment on Windows
#   - pacman package manager
#
# Test hook for brother instances on MSYS2:
#   source ~/.onetimesetup.sh && source ~/.onetimesetup_msys2.sh
#   LGREEN_ONETIMESETUP_DRYRUN=1 lgreen_onetimesetup_run_all
#
# Note: These tasks are UNTESTED - forced to dry-run mode for safety
#       Remove forced dry-run after testing on actual MSYS2 environment

# =============================================================================
# MSYS2-Specific Tasks
# =============================================================================

lgreen_onetimesetup_msys2_oh_my_posh() {
    _onetimesetup_log "==> Install Oh-My-Posh (MSYS2)"
    _onetimesetup_log ""
    _onetimesetup_log "  ⚠️  UNTESTED - Forced dry-run mode"
    _onetimesetup_log "  Test on actual MSYS2 before enabling"
    _onetimesetup_log ""

    if ! command -v pacman >/dev/null 2>&1; then
        _onetimesetup_log "  ⚠ pacman not found, skipping"
        return 0
    fi

    # FORCE dry-run until tested
    local FORCED_DRYRUN=true

    if _onetimesetup_is_dryrun || [ "$FORCED_DRYRUN" = true ]; then
        _onetimesetup_log "  DRYRUN: Would run: pacman -S mingw64/mingw-w64-x86_64-oh-my-posh"
        _onetimesetup_log "  DRYRUN: Package provides shell prompt theming"
    else
        _onetimesetup_log "  Installing oh-my-posh..."
        if pacman -S --noconfirm mingw64/mingw-w64-x86_64-oh-my-posh; then
            _onetimesetup_log "  ✓ Oh-My-Posh installed"
        else
            _onetimesetup_log "  ✗ Installation failed"
            return 1
        fi
    fi

    lgreen_onetimesetup_record_task "msys2_oh_my_posh"
}

# =============================================================================
# Platform Hook (called by common infrastructure)
# =============================================================================

lgreen_onetimesetup_run_platform() {
    # Detect MSYS2 environment
    if [ -z "$MSYSTEM" ]; then
        _onetimesetup_log "MSYS2 environment not detected (MSYSTEM not set), skipping"
        return 0
    fi

    _onetimesetup_log "Platform detected: MSYS2 ($MSYSTEM)"
    _onetimesetup_log ""

    lgreen_onetimesetup_msys2_oh_my_posh
}
