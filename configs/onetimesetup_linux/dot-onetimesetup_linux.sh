#!/usr/bin/env sh
# Onetime setup tasks - Linux specific
#
# Prerequisites:
#   - Must source ~/.onetimesetup.sh first (provides infrastructure)
#   - Requires: curl, fc-cache
#
# Test hook:
#   source ~/.onetimesetup.sh && source ~/.onetimesetup_linux.sh
#   LGREEN_ONETIMESETUP_DRYRUN=1 lgreen_onetimesetup_run_all

# =============================================================================
# Linux-Specific Tasks
# =============================================================================

lgreen_onetimesetup_linux_nerd_font() {
    _onetimesetup_log "==> Installing Nerd Font (Iosevka)"

    if ! command -v curl >/dev/null 2>&1; then
        _onetimesetup_log "  ⚠ curl not installed, skipping"
        return 0
    fi

    local font_dir="$HOME/.local/share/fonts"
    local font_file="IosevkaNerdFont-Regular.ttf"
    local font_path="$font_dir/$font_file"

    if [ -f "$font_path" ]; then
        _onetimesetup_log "  ✓ Already installed: $font_path"
        return 0
    fi

    if _onetimesetup_is_dryrun; then
        _onetimesetup_log "  DRYRUN: Would create $font_dir"
        _onetimesetup_log "  DRYRUN: Would download to $font_path"
        _onetimesetup_log "  DRYRUN: Would run fc-cache -fv"
        lgreen_onetimesetup_record_task "linux_nerd_font"
        return 0
    fi

    _onetimesetup_log "  Creating fonts directory..."
    mkdir -p "$font_dir"

    _onetimesetup_log "  Downloading Iosevka Nerd Font..."
    if curl -fLo "$font_path" \
        "https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/Iosevka/IosevkaNerdFont-Regular.ttf"; then

        _onetimesetup_log "  Updating font cache..."
        if command -v fc-cache >/dev/null 2>&1; then
            fc-cache -fv >/dev/null 2>&1
        fi

        _onetimesetup_log "  ✓ Nerd font installed: $font_path"
        lgreen_onetimesetup_record_task "linux_nerd_font"
    else
        _onetimesetup_log "  ✗ Download failed"
        return 1
    fi
}

lgreen_onetimesetup_linux_minimap_font() {
    _onetimesetup_log "==> Installing Minimap Font"

    if ! command -v curl >/dev/null 2>&1; then
        _onetimesetup_log "  ⚠ curl not installed, skipping"
        return 0
    fi

    local font_dir="$HOME/.local/share/fonts"
    local font_file="Minimap.ttf"
    local font_path="$font_dir/$font_file"

    if [ -f "$font_path" ]; then
        _onetimesetup_log "  ✓ Already installed: $font_path"
        return 0
    fi

    if _onetimesetup_is_dryrun; then
        _onetimesetup_log "  DRYRUN: Would create $font_dir"
        _onetimesetup_log "  DRYRUN: Would download to $font_path"
        _onetimesetup_log "  DRYRUN: Would run fc-cache -fv"
        lgreen_onetimesetup_record_task "linux_minimap_font"
        return 0
    fi

    _onetimesetup_log "  Creating fonts directory..."
    mkdir -p "$font_dir"

    _onetimesetup_log "  Downloading Minimap font..."
    if curl -fLo "$font_path" \
        "https://github.com/davestewart/minimap-font/raw/master/src/Minimap.ttf"; then

        _onetimesetup_log "  Updating font cache..."
        if command -v fc-cache >/dev/null 2>&1; then
            fc-cache -fv >/dev/null 2>&1
        fi

        _onetimesetup_log "  ✓ Minimap font installed: $font_path"
        lgreen_onetimesetup_record_task "linux_minimap_font"
    else
        _onetimesetup_log "  ✗ Download failed"
        return 1
    fi
}

# =============================================================================
# Platform Hook (called by common infrastructure)
# =============================================================================

lgreen_onetimesetup_run_platform() {
    _onetimesetup_log "Platform detected: Linux"
    _onetimesetup_log ""

    lgreen_onetimesetup_linux_nerd_font
    lgreen_onetimesetup_linux_minimap_font
}
