#!/usr/bin/env sh
# Onetime setup tasks - WSL specific
#
# Prerequisites:
#   - Must source ~/.onetimesetup.sh first (provides infrastructure)
#   - WSL detection: check /proc/sys/fs/binfmt_misc/WSLInterop
#   - Requires: zsh, chsh
#
# Test hook for brother instances on WSL:
#   source ~/.onetimesetup.sh && source ~/.onetimesetup_wsl.sh
#   LGREEN_ONETIMESETUP_DRYRUN=1 lgreen_onetimesetup_run_all

# =============================================================================
# WSL-Specific Tasks
# =============================================================================

lgreen_onetimesetup_wsl_default_shell() {
    _onetimesetup_log "==> Set Zsh as Default Shell"

    if ! command -v zsh >/dev/null 2>&1; then
        _onetimesetup_log "  ⚠ zsh not installed, skipping"
        return 0
    fi

    local zsh_path
    zsh_path=$(command -v zsh)

    local current_shell
    current_shell=$(getent passwd "$USER" 2>/dev/null | cut -d: -f7)

    if [ "$current_shell" = "$zsh_path" ]; then
        _onetimesetup_log "  ✓ Already using zsh as default shell"
        return 0
    fi

    if _onetimesetup_is_dryrun; then
        _onetimesetup_log "  Current shell: $current_shell"
        _onetimesetup_log "  DRYRUN: Would run: chsh -s $zsh_path"
        _onetimesetup_log "  DRYRUN: May require password"
        lgreen_onetimesetup_record_task "wsl_default_shell"
        return 0
    fi

    _onetimesetup_log "  Current shell: $current_shell"
    _onetimesetup_log "  Changing default shell to $zsh_path..."
    _onetimesetup_log "  (may require password)"

    if chsh -s "$zsh_path"; then
        _onetimesetup_log "  ✓ Default shell set to zsh"
        _onetimesetup_log "  Note: Logout and login again for change to take effect"
        lgreen_onetimesetup_record_task "wsl_default_shell"
    else
        _onetimesetup_log "  ✗ Failed to change shell (may need sudo or valid shell in /etc/shells)"
        return 1
    fi
}

# =============================================================================
# Platform Hook (called by common infrastructure)
# =============================================================================

lgreen_onetimesetup_run_platform() {
    # Only run if actually in WSL
    if [ ! -f /proc/sys/fs/binfmt_misc/WSLInterop ]; then
        _onetimesetup_log "WSL not detected, skipping WSL-specific tasks"
        return 0
    fi

    _onetimesetup_log "Platform detected: WSL (Windows Subsystem for Linux)"
    _onetimesetup_log ""

    lgreen_onetimesetup_wsl_default_shell
}
