function lgreen-setup-powershell-modules {
    Install-Module -Name PSReadLine -Scope CurrentUser
    Install-Module -Name CompletionPredictor -Scope CurrentUser
    Install-Module -Name PSFzf -Scope CurrentUser
}

function lgreen-setup-scheduled-task-for-divvy {

    $ProgramPath = "$env:LOCALAPPDATA\Mizage LLC\Divvy\Divvy.exe"
    if (-not (Test-path $ProgramPath)) {
        throw "$ProgramPath does not exist"
    }
    $Action = New-ScheduledTaskAction -Execute "$ProgramPath"

    $CurrentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $Principal = New-ScheduledTaskPrincipal -UserId $CurrentUser.User.Value -LogonType Interactive -RunLevel Highest

    $Trigger = New-ScheduledTaskTrigger -AtLogon -User $CurrentUser.Name
    $Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

    Register-ScheduledTask `
        -TaskPath "$($CurrentUser.Name) Tasks".Replace("\", "-") `
        -TaskName "Run Divvy" `
        -Action $Action `
        -Trigger $Trigger `
        -Principal $Principal `
        -Settings $Settings
}

function lgreen-setup-firewall-forward-ssh-to-wsl-sshd {
    # Get WSL IP address
    wsl hostname -I | Set-Variable -Name "wslAddress"
    $found = $wslAddress -match '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}';
    if (-not $found) {
      echo "WSL2 cannot be found. Terminate script.";
      exit;
    }

    $sshdPort = 22

    # Create firewall rule
    Remove-NetFireWallRule -DisplayName 'LGREEN SETUP - WSL2 SSHD'
    New-NetFireWallRule -DisplayName 'LGREEN SETUP - WSL2 SSHD' -Direction Inbound -LocalPort $sshdPort -Action Allow -Protocol TCP

    # Forward ports
    iex "netsh interface portproxy delete v4tov4 listenaddress=0.0.0.0 listenport=$sshdPort"
    iex "netsh interface portproxy add v4tov4 listenaddress=0.0.0.0 listenport=$sshdPort connectaddress=$wslAddress connectport=2222"

    # Display all portproxy information
    iex "netsh interface portproxy show v4tov4"
}
