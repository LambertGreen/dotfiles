#!/usr/bin/env sh
# Onetime setup tasks - Windows specific
#
# Prerequisites:
#   - Must source ~/.onetimesetup.sh first (provides infrastructure)
#   - Windows environment (PowerShell, scoop, chocolatey, winget)
#
# IMPORTANT: These are SHELL STUBS for PowerShell commands
#            Most tasks require PowerShell execution
#            Kept in discoverable form for reference
#
# Test hook:
#   source ~/.onetimesetup.sh && source ~/.onetimesetup_win.sh
#   LGREEN_ONETIMESETUP_DRYRUN=1 lgreen_onetimesetup_run_all

# =============================================================================
# Windows-Specific Tasks (PowerShell-based, shell stubs for discoverability)
# =============================================================================

lgreen_onetimesetup_win_powershell_modules() {
    _onetimesetup_log "==> Install PowerShell Modules"
    _onetimesetup_log ""
    _onetimesetup_log "  ⚠️  SHELL STUB - Requires PowerShell execution"
    _onetimesetup_log "  PowerShell commands to run manually:"
    _onetimesetup_log ""
    _onetimesetup_log "    Install-Module -Name PSReadLine -Scope CurrentUser"
    _onetimesetup_log "    Install-Module -Name CompletionPredictor -Scope CurrentUser"
    _onetimesetup_log "    Install-Module -Name PSFzf -Scope CurrentUser"
    _onetimesetup_log "    Install-Module -Name Get-ChildItemColor -Scope CurrentUser"
    _onetimesetup_log "    Install-Module -Name z -Scope CurrentUser"
    _onetimesetup_log "    Install-Module -Name posh-git -Scope CurrentUser"
    _onetimesetup_log ""
    _onetimesetup_log "  STUB: Cannot execute PowerShell from sh script"

    lgreen_onetimesetup_record_task "win_powershell_modules_info_shown"
}

lgreen_onetimesetup_win_scoop_buckets() {
    _onetimesetup_log "==> Configure Scoop Buckets"
    _onetimesetup_log ""
    _onetimesetup_log "  ⚠️  SHELL STUB - Requires PowerShell execution"
    _onetimesetup_log "  PowerShell commands to run manually:"
    _onetimesetup_log ""
    _onetimesetup_log "    scoop bucket add nerd-fonts"
    _onetimesetup_log ""
    _onetimesetup_log "  STUB: Cannot execute PowerShell from sh script"

    lgreen_onetimesetup_record_task "win_scoop_buckets_info_shown"
}

lgreen_onetimesetup_win_scoop_global_apps() {
    _onetimesetup_log "==> Install Scoop Global Apps"
    _onetimesetup_log ""
    _onetimesetup_log "  ⚠️  SHELL STUB - Requires PowerShell execution"
    _onetimesetup_log "  PowerShell commands to run manually:"
    _onetimesetup_log ""
    _onetimesetup_log "    sudo scoop install clink -g"
    _onetimesetup_log ""
    _onetimesetup_log "  Note: clink install path referenced in WindowsCommand\\dev.cmd"
    _onetimesetup_log "  STUB: Cannot execute PowerShell from sh script"

    lgreen_onetimesetup_record_task "win_scoop_global_apps_info_shown"
}

lgreen_onetimesetup_win_choco_apps() {
    _onetimesetup_log "==> Install Chocolatey Apps"
    _onetimesetup_log ""
    _onetimesetup_log "  ⚠️  SHELL STUB - Requires PowerShell execution"
    _onetimesetup_log "  PowerShell commands to run manually:"
    _onetimesetup_log ""
    _onetimesetup_log "    sudo choco install git"
    _onetimesetup_log ""
    _onetimesetup_log "  Note: git install path referenced in shell_msys2/dot-profile_msys2"
    _onetimesetup_log "  STUB: Cannot execute PowerShell from sh script"

    lgreen_onetimesetup_record_task "win_choco_apps_info_shown"
}

lgreen_onetimesetup_win_oh_my_posh() {
    _onetimesetup_log "==> Install Oh-My-Posh Prompt"
    _onetimesetup_log ""
    _onetimesetup_log "  ⚠️  SHELL STUB - Requires PowerShell execution"
    _onetimesetup_log "  PowerShell commands to run manually:"
    _onetimesetup_log ""
    _onetimesetup_log "    winget install JanDeDobbeleer.OhMyPosh -s winget"
    _onetimesetup_log ""
    _onetimesetup_log "  STUB: Cannot execute PowerShell from sh script"

    lgreen_onetimesetup_record_task "win_oh_my_posh_info_shown"
}

lgreen_onetimesetup_win_clink_fzf() {
    _onetimesetup_log "==> Setup Clink FZF Integration"
    _onetimesetup_log ""
    _onetimesetup_log "  ⚠️  MANUAL SETUP REQUIRED"
    _onetimesetup_log "  Steps:"
    _onetimesetup_log ""
    _onetimesetup_log "    1. cd ~/dev/pub"
    _onetimesetup_log "    2. git clone git@github.com:chrisant996/clink-fzf.git"
    _onetimesetup_log "    3. cd clink-fzf"
    _onetimesetup_log "    4. cp *.lua ~/AppData/Local/clink"
    _onetimesetup_log ""
    _onetimesetup_log "  STUB: Manual clone preferred"

    lgreen_onetimesetup_record_task "win_clink_fzf_info_shown"
}

lgreen_onetimesetup_win_clink_flex_prompt() {
    _onetimesetup_log "==> Setup Clink Flex Prompt"
    _onetimesetup_log ""
    _onetimesetup_log "  ⚠️  MANUAL SETUP REQUIRED"
    _onetimesetup_log "  Steps:"
    _onetimesetup_log ""
    _onetimesetup_log "    1. cd ~/dev/pub"
    _onetimesetup_log "    2. git clone git@github.com:chrisant996/clink-flex-prompt.git"
    _onetimesetup_log "    3. cd clink-flex-prompt"
    _onetimesetup_log "    4. cp *.lua ~/AppData/Local/clink"
    _onetimesetup_log ""
    _onetimesetup_log "  STUB: Manual clone preferred"

    lgreen_onetimesetup_record_task "win_clink_flex_prompt_info_shown"
}

lgreen_onetimesetup_win_divvy_scheduled_task() {
    _onetimesetup_log "==> Create Divvy Scheduled Task"
    _onetimesetup_log ""
    _onetimesetup_log "  ⚠️  COMPLEX POWERSHELL - Not ported"
    _onetimesetup_log "  This task creates a scheduled task to auto-start Divvy"
    _onetimesetup_log "  See: deprecated/setup_win/setup.ps1"
    _onetimesetup_log "  Function: lgreen-setup-scheduled-task-for-divvy"
    _onetimesetup_log ""
    _onetimesetup_log "  Too complex for shell stub - use PowerShell directly"

    lgreen_onetimesetup_record_task "win_divvy_info_shown"
}

lgreen_onetimesetup_win_wsl_ssh_forwarding() {
    _onetimesetup_log "==> Configure WSL SSH Port Forwarding"
    _onetimesetup_log ""
    _onetimesetup_log "  ⚠️  COMPLEX NETWORK CONFIG - Not ported"
    _onetimesetup_log "  This task sets up Windows firewall + port proxy for WSL sshd"
    _onetimesetup_log "  See: deprecated/setup_win/setup.ps1"
    _onetimesetup_log "  Function: lgreen-setup-firewall-forward-ssh-to-wsl-sshd"
    _onetimesetup_log ""
    _onetimesetup_log "  Too complex for shell stub - use PowerShell directly"

    lgreen_onetimesetup_record_task "win_wsl_ssh_info_shown"
}

lgreen_onetimesetup_win_office_key_fix() {
    _onetimesetup_log "==> Office Key Fix (Hyper Key)"
    _onetimesetup_log ""
    _onetimesetup_log "  ⚠️  EXTERNAL PROJECT - Not included"
    _onetimesetup_log "  Manual steps:"
    _onetimesetup_log ""
    _onetimesetup_log "    1. git clone https://github.com/LambertGreen/OfficeKeyFix"
    _onetimesetup_log "    2. Build and configure"
    _onetimesetup_log ""
    _onetimesetup_log "  External project, not dotfiles concern"

    lgreen_onetimesetup_record_task "win_office_key_fix_info_shown"
}

lgreen_onetimesetup_win_msys2_env_vars() {
    _onetimesetup_log "==> Configure MSYS2 Environment Variables"
    _onetimesetup_log ""
    _onetimesetup_log "  ⚠️  SHELL STUB - Requires PowerShell execution"
    _onetimesetup_log "  PowerShell commands to run manually:"
    _onetimesetup_log ""
    _onetimesetup_log "    [Environment]::SetEnvironmentVariable(\"MSYS\", \"winsymlinks:nativestrict\", \"User\")"
    _onetimesetup_log "    [Environment]::SetEnvironmentVariable(\"MSYS2_PATH_TYPE\", \"strict\", \"User\")"
    _onetimesetup_log ""
    _onetimesetup_log "  Purpose:"
    _onetimesetup_log "    - Enable native Windows symlinks (required for GNU Stow)"
    _onetimesetup_log "    - Use strict PATH mode for performance"
    _onetimesetup_log ""
    _onetimesetup_log "  Note: Restart MSYS2 terminals after setting"
    _onetimesetup_log "  STUB: Cannot execute PowerShell from sh script"

    lgreen_onetimesetup_record_task "win_msys2_env_vars_info_shown"
}

# =============================================================================
# Platform Hook (called by common infrastructure)
# =============================================================================

lgreen_onetimesetup_run_platform() {
    # Detect Windows environment (crude check)
    if [ -z "$WINDIR" ] && [ ! -d "/c/Windows" ] && [ ! -d "/mnt/c/Windows" ]; then
        _onetimesetup_log "Windows environment not detected, skipping"
        return 0
    fi

    _onetimesetup_log "Platform detected: Windows"
    _onetimesetup_log ""
    _onetimesetup_log "⚠️  NOTE: Most Windows tasks are SHELL STUBS"
    _onetimesetup_log "⚠️  They document PowerShell commands for manual execution"
    _onetimesetup_log ""

    lgreen_onetimesetup_win_powershell_modules
    lgreen_onetimesetup_win_scoop_buckets
    lgreen_onetimesetup_win_scoop_global_apps
    lgreen_onetimesetup_win_choco_apps
    lgreen_onetimesetup_win_oh_my_posh
    lgreen_onetimesetup_win_clink_fzf
    lgreen_onetimesetup_win_clink_flex_prompt
    lgreen_onetimesetup_win_divvy_scheduled_task
    lgreen_onetimesetup_win_wsl_ssh_forwarding
    lgreen_onetimesetup_win_office_key_fix
    lgreen_onetimesetup_win_msys2_env_vars
}
