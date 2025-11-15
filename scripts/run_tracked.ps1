# PowerShell script to run a command with tracking, logging, and clean output
param(
    [Parameter(Mandatory=$true)]
    [string]$Operation,

    [Parameter(Mandatory=$true)]
    [string]$Command,

    [Parameter(Mandatory=$true)]
    [string]$LogFile,

    [Parameter(Mandatory=$true)]
    [string]$StatusFile,

    [Parameter(Mandatory=$false)]
    [string]$AutoClose = "false"
)

# Clear for clean start
Clear-Host

# Header
Write-Host "🚀 $Operation" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host "Command: $Command"
Write-Host "Command length: $($Command.Length)"
Write-Host ""

# Ensure log and status directories exist
$logDir = Split-Path -Parent $LogFile
$statusDir = Split-Path -Parent $StatusFile
if ($logDir -and -not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
if ($statusDir -and -not (Test-Path $statusDir)) { New-Item -ItemType Directory -Path $statusDir -Force | Out-Null }

# Write starting status
$timestamp = [int][double]::Parse((Get-Date -UFormat %s))
$startStatus = @{
    status = "running"
    timestamp = $timestamp
    operation = $Operation
} | ConvertTo-Json -Compress
Set-Content -Path $StatusFile -Value $startStatus

# Run command with output capture (like tee)
$exitCode = 0
try {
    # Write command to temporary batch file to avoid PowerShell parameter parsing issues
    $tempBatch = [System.IO.Path]::GetTempFileName() -replace '\.tmp$', '.bat'
    $Command | Out-File -FilePath $tempBatch -Encoding ASCII -NoNewline
    try {
        # Execute the batch file
        cmd.exe /c $tempBatch 2>&1 | Tee-Object -FilePath $LogFile
        $exitCode = $LASTEXITCODE
        if ($null -eq $exitCode) { $exitCode = 0 }
    } finally {
        # Clean up temp file
        if (Test-Path $tempBatch) {
            Remove-Item $tempBatch -Force -ErrorAction SilentlyContinue
        }
    }
} catch {
    Write-Host "Error executing command: $_" -ForegroundColor Red
    $exitCode = 1
}

# Write completion status
$timestamp = [int][double]::Parse((Get-Date -UFormat %s))
$completeStatus = @{
    status = "completed"
    exit_code = $exitCode
    timestamp = $timestamp
    operation = $Operation
} | ConvertTo-Json -Compress
Set-Content -Path $StatusFile -Value $completeStatus

# Footer
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if ($exitCode -eq 0) {
    Write-Host "✅ $Operation completed successfully" -ForegroundColor Green
    if ($AutoClose -eq "true") {
        Start-Sleep -Seconds 1
    } else {
        Write-Host ""
        Write-Host "🖥️  Terminal ready for closure via automation"
    }
} else {
    Write-Host "❌ $Operation failed (exit code: $exitCode)" -ForegroundColor Red
    Write-Host ""
    Write-Host "📄 Log saved to: $LogFile"
    Write-Host ""
    Write-Host "🖥️  Terminal ready for closure via automation"
}
