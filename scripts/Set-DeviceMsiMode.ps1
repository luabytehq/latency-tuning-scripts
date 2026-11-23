<#
.SYNOPSIS
    LuaByte Safe Message Signaled Interrupts (MSI Mode) Manager.
.DESCRIPTION
    Safely inspects, backs up, and toggles Message Signaled Interrupts (MSI Mode)
    and Interrupt Priorities for GPUs and USB host controllers in Windows.
    Companion script to https://luabyte.com/blog/system/configure-msi-mode-windows-input-lag
.PARAMETER List
    Lists all detected PCI devices with their current MSI state and Interrupt Priority.
.PARAMETER Type
    Target device category: 'GPU', 'USB', or 'All'.
.PARAMETER Enable
    Enables MSI Mode (MSISupported = 1) for the target device(s).
.PARAMETER Disable
    Disables MSI Mode (MSISupported = 0), reverting to legacy line-based pin IRQs.
.PARAMETER Priority
    Sets device interrupt priority: 'Undefined', 'Low', 'Normal', or 'High'.
.PARAMETER SkipBackup
    Skips the automatic .reg backup step before applying changes (not recommended).
.EXAMPLE
    .\Set-DeviceMsiMode.ps1 -List
.EXAMPLE
    .\Set-DeviceMsiMode.ps1 -Type GPU -Enable -Priority High
#>

[CmdletBinding()]
param (
    [switch]$List,
    [ValidateSet('GPU', 'USB', 'All')]
    [string]$Type,
    [switch]$Enable,
    [switch]$Disable,
    [ValidateSet('Undefined', 'Low', 'Normal', 'High')]
    [string]$Priority,
    [switch]$SkipBackup
)

# Ensure elevated administrator privileges
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Set-DeviceMsiMode requires Administrator privileges to modify hardware interrupt registries."
    Write-Host "Please re-run this script in an elevated PowerShell session (Run as Administrator)." -ForegroundColor Yellow
    exit 1
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$BackupDir = Join-Path $ScriptDir "..\backups"
if (-not (Test-Path $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
}

function Show-Banner {
    Write-Host "=============================================================" -ForegroundColor Cyan
    Write-Host " LuaByte MSI Mode Optimization Manager v1.0.0" -ForegroundColor White
    Write-Host " Engineering Guide: https://luabyte.com" -ForegroundColor Gray
    Write-Host "=============================================================" -ForegroundColor Cyan
}

function Get-PciDevices {
    $pciRoot = "HKLM:\SYSTEM\CurrentControlSet\Enum\PCI"
    $devices = @()

    if (-not (Test-Path $pciRoot)) {
        Write-Error "PCI registry path not found."
        return $devices
    }

    $subKeys = Get-ChildItem -Path $pciRoot -ErrorAction SilentlyContinue

    foreach ($key in $subKeys) {
        $instances = Get-ChildItem -Path $key.PSPath -ErrorAction SilentlyContinue
        foreach ($inst in $instances) {
            $deviceDesc = (Get-ItemProperty -Path $inst.PSPath -Name "DeviceDesc" -ErrorAction SilentlyContinue).DeviceDesc
            $class = (Get-ItemProperty -Path $inst.PSPath -Name "Class" -ErrorAction SilentlyContinue).Class
            $friendlyName = (Get-ItemProperty -Path $inst.PSPath -Name "FriendlyName" -ErrorAction SilentlyContinue).FriendlyName

            $name = if ($friendlyName) { $friendlyName } elseif ($deviceDesc) { $deviceDesc.Split(';')[-1] } else { $inst.PSChildName }

            $msiPath = Join-Path $inst.PSPath "Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
            $hasMsiKey = Test-Path $msiPath

            $msiSupported = $null
            $devicePriority = $null

            if ($hasMsiKey) {
                $props = Get-ItemProperty -Path $msiPath -ErrorAction SilentlyContinue
                if ($props.PSObject.Properties.Match("MSISupported").Count -gt 0) {
                    $msiSupported = [bool]$props.MSISupported
                }
                if ($props.PSObject.Properties.Match("DevicePriority").Count -gt 0) {
                    $devicePriority = switch ($props.DevicePriority) {
                        1 { "Low" }
                        2 { "Normal" }
                        3 { "High" }
                        default { "Undefined" }
                    }
                } else {
                    $devicePriority = "Undefined"
                }
            }

            $category = "Other"
            if ($class -eq "Display" -or $name -match "NVIDIA|GeForce|Radeon|Intel\(R\) (U?HD|Iris|Arc)") {
                $category = "GPU"
            } elseif ($class -eq "USB" -or $name -match "xHCI|Host Controller|USB") {
                $category = "USB"
            }

            $devices += [PSCustomObject]@{
                Name            = $name
                Category        = $category
                Class           = $class
                MsiPath         = $msiPath
                HasMsiKey       = $hasMsiKey
                MsiSupported    = $msiSupported
                InterruptPriority = $devicePriority
                RegistryPath    = $inst.PSPath
            }
        }
    }

    return $devices
}

function Backup-MsiRegistry {
    $timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
    $backupFile = Join-Path $BackupDir "msi_backup_$timestamp.reg"
    Write-Host "[Backup] Exporting registry backup to: $backupFile" -ForegroundColor Green
    Start-Process "reg.exe" -ArgumentList "export HKLM\SYSTEM\CurrentControlSet\Enum\PCI `"$backupFile`"" -Wait -NoNewWindow
    if (Test-Path $backupFile) {
        Write-Host "[Backup] Backup verified successfully ($((Get-Item $backupFile).Length) bytes)." -ForegroundColor Green
    } else {
        Write-Warning "[Backup] Could not verify registry backup file creation."
    }
}

Show-Banner

# Default action: list devices if no modification flags are passed
if ($List -or (-not $Enable -and -not $Disable -and -not $Priority)) {
    Write-Host "`n[+] Scanning PCI Configuration Space for Interrupt Modes...`n" -ForegroundColor Yellow
    $allDevices = Get-PciDevices | Where-Object { $_.Category -in @("GPU", "USB") }

    $displayList = $allDevices | Select-Object @(
        @{Name = "Category"; Expression = { $_.Category }},
        @{Name = "Device Name"; Expression = { if ($_.Name.Length -gt 45) { $_.Name.Substring(0, 42) + "..." } else { $_.Name } }},
        @{Name = "MSI Status"; Expression = { if ($_.MsiSupported -eq $true) { "ENABLED" } elseif ($_.MsiSupported -eq $false) { "DISABLED" } else { "NOT CONFIGURED" } }},
        @{Name = "Priority"; Expression = { $_.InterruptPriority }}
    )

    $displayList | Format-Table -AutoSize
    Write-Host "To configure MSI mode: .\Set-DeviceMsiMode.ps1 -Type GPU -Enable -Priority High" -ForegroundColor Cyan
    exit 0
}

# Perform automatic registry backup before modifying
if (-not $SkipBackup) {
    Backup-MsiRegistry
}

$targetCategory = if ($Type) { $Type } else { "All" }
$targets = Get-PciDevices | Where-Object {
    if ($targetCategory -eq "All") {
        $_.Category -in @("GPU", "USB")
    } else {
        $_.Category -eq $targetCategory
    }
}

if ($targets.Count -eq 0) {
    Write-Warning "No devices found matching category '$targetCategory'."
    exit 0
}

Write-Host "`n[+] Applying configuration to $($targets.Count) device(s) in category [$targetCategory]..." -ForegroundColor Yellow

foreach ($dev in $targets) {
    if (-not (Test-Path $dev.MsiPath)) {
        New-Item -Path $dev.MsiPath -Force | Out-Null
    }

    if ($Enable) {
        Set-ItemProperty -Path $dev.MsiPath -Name "MSISupported" -Value 1 -Type DWord -Force
        Write-Host " [OK] Enabled MSI Mode for: $($dev.Name)" -ForegroundColor Green
    } elseif ($Disable) {
        Set-ItemProperty -Path $dev.MsiPath -Name "MSISupported" -Value 0 -Type DWord -Force
        Write-Host " [OK] Disabled MSI Mode for: $($dev.Name)" -ForegroundColor Yellow
    }

    if ($Priority) {
        $priorityDword = switch ($Priority) {
            "Low" { 1 }
            "Normal" { 2 }
            "High" { 3 }
            default { 0 }
        }
        if ($priorityDword -gt 0) {
            Set-ItemProperty -Path $dev.MsiPath -Name "DevicePriority" -Value $priorityDword -Type DWord -Force
            Write-Host " [OK] Set InterruptPriority to $Priority for: $($dev.Name)" -ForegroundColor Green
        }
    }
}

Write-Host "`n[+] Changes applied successfully. A system restart is required for hardware interrupt remapping." -ForegroundColor Cyan
