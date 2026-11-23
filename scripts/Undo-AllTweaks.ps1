<#
.SYNOPSIS
    LuaByte Revert & Restoration Tool.
.DESCRIPTION
    Restores hardware interrupt settings from the latest registry backup,
    or resets device interrupt priorities back to default Windows configurations.
.PARAMETER BackupFile
    Optional explicit path to a .reg backup file to import.
.EXAMPLE
    .\Undo-AllTweaks.ps1
.EXAMPLE
    .\Undo-AllTweaks.ps1 -BackupFile ..\backups\msi_backup_20261123_120000.reg
#>

[CmdletBinding()]
param (
    [string]$BackupFile
)

# Ensure elevated administrator privileges
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Undo-AllTweaks requires Administrator privileges to restore registry settings."
    Write-Host "Please re-run this script in an elevated PowerShell session (Run as Administrator)." -ForegroundColor Yellow
    exit 1
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$BackupDir = Join-Path $ScriptDir "..\backups"

Write-Host "=============================================================" -ForegroundColor Cyan
Write-Host " LuaByte Latency Toolkit - Revert & Restore" -ForegroundColor White
Write-Host "=============================================================" -ForegroundColor Cyan

if ($BackupFile) {
    if (-not (Test-Path $BackupFile)) {
        Write-Error "Specified backup file does not exist: $BackupFile"
        exit 1
    }
    $targetFile = $BackupFile
} else {
    # Find latest backup in backups directory
    $latestBackup = Get-ChildItem -Path $BackupDir -Filter "*.reg" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $latestBackup) {
        Write-Warning "No .reg backup files found in $BackupDir."
        Write-Host "Resetting GPU and USB MSI overrides back to defaults directly..." -ForegroundColor Yellow

        $pciRoot = "HKLM:\SYSTEM\CurrentControlSet\Enum\PCI"
        $keys = Get-ChildItem -Path $pciRoot -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -eq "MessageSignaledInterruptProperties" }
        foreach ($k in $keys) {
            Remove-ItemProperty -Path $k.PSPath -Name "DevicePriority" -ErrorAction SilentlyContinue
            Write-Host " Reset priority on: $($k.PSPath)" -ForegroundColor Gray
        }
        Write-Host "`n[OK] Device overrides cleared. Restart your PC to apply default configuration." -ForegroundColor Green
        exit 0
    }
    $targetFile = $latestBackup.FullName
}

Write-Host "[Restore] Importing registry state from: $targetFile" -ForegroundColor Yellow
$proc = Start-Process "reg.exe" -ArgumentList "import `"$targetFile`"" -Wait -PassThru -NoNewWindow

if ($proc.ExitCode -eq 0) {
    Write-Host "`n[OK] Registry successfully restored from backup!" -ForegroundColor Green
    Write-Host "Please restart your computer for changes to take full effect." -ForegroundColor Cyan
} else {
    Write-Error "Failed to import registry file. reg.exe exited with code $($proc.ExitCode)"
}
