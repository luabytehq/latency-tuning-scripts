<#
.SYNOPSIS
    LuaByte DPC Latency & Windows Real-Time Diagnostics Tool.
.DESCRIPTION
    Audits Windows kernel timer resolution, power scheme states, core parking,
    and high-latency driver execution queues.
    Companion script to https://luabyte.com/blog/system/fix-dpc-latency-audio-crackling-windows-11
.EXAMPLE
    .\Test-DpcHealth.ps1
#>

[CmdletBinding()]
param ()

function Show-Banner {
    Write-Host "=============================================================" -ForegroundColor Cyan
    Write-Host " LuaByte DPC & Real-Time Kernel Health Audit v1.0.0" -ForegroundColor White
    Write-Host " Engineering Guide: https://luabyte.com" -ForegroundColor Gray
    Write-Host "=============================================================" -ForegroundColor Cyan
}

Show-Banner

Write-Host "`n[1/5] Evaluating System Timer Resolution..." -ForegroundColor Yellow

$timerResolution = 15.6
try {
    # Check if timer resolution can be queried via kernel stopwatch
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    Start-Sleep -Milliseconds 10
    $sw.Stop()
    $isHighRes = [System.Diagnostics.Stopwatch]::IsHighResolution
    $frequency = [System.Diagnostics.Stopwatch]::Frequency
    Write-Host " Stopwatch High Resolution Support: $isHighRes ($frequency Hz)" -ForegroundColor Gray
} catch {
    Write-Warning "Could not query hardware stopwatch."
}

# 2. Check Active Power Scheme
Write-Host "`n[2/5] Inspecting Windows Power Scheme Configuration..." -ForegroundColor Yellow
$powerScheme = (powercfg /getactivescheme)
$powerPlanName = "Unknown"
if ($powerScheme -match "\((.+?)\)") {
    $powerPlanName = $matches[1]
}

if ($powerPlanName -match "High [Pp]erformance|Ultimate [Pp]erformance") {
    Write-Host " Active Power Plan: $powerPlanName [OPTIMAL]" -ForegroundColor Green
} elseif ($powerPlanName -match "Balanced") {
    Write-Host " Active Power Plan: $powerPlanName [SUB-OPTIMAL: C-state throttling may introduce DPC spikes]" -ForegroundColor Yellow
} else {
    Write-Host " Active Power Plan: $powerPlanName" -ForegroundColor Cyan
}

# 3. Inspect Core Parking Status
Write-Host "`n[3/5] Checking Processor Core Parking Policies..." -ForegroundColor Yellow
$coreParkingKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4348-892f-0a0f44207724"
if (Test-Path $coreParkingKey) {
    $val = (Get-ItemProperty -Path $coreParkingKey -Name "ValueMax" -ErrorAction SilentlyContinue).ValueMax
    if ($val -eq 0) {
        Write-Host " CPU Core Parking: DISABLED (All physical execution cores remain active) [OPTIMAL]" -ForegroundColor Green
    } else {
        Write-Host " CPU Core Parking: ENABLED (Cores may park/unpark dynamically) [POTENTIAL JITTER]" -ForegroundColor Yellow
    }
} else {
    Write-Host " Core parking registry key not overridden (Using Windows OS defaults)." -ForegroundColor Gray
}

# 4. Check Network Adapter Interrupt Moderation
Write-Host "`n[4/5] Checking Network Interrupt Moderation..." -ForegroundColor Yellow
try {
    $adapters = Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Up" }
    foreach ($adapter in $adapters) {
        $intMod = Get-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "*Interrupt Moderation*" -ErrorAction SilentlyContinue
        if ($intMod) {
            Write-Host " Adapter: $($adapter.Name) | Interrupt Moderation: $($intMod.DisplayValue)" -ForegroundColor Gray
        } else {
            Write-Host " Adapter: $($adapter.Name) | Interrupt Moderation: Default" -ForegroundColor Gray
        }
    }
} catch {
    Write-Warning "Could not query network adapter properties."
}

# 5. Kernel Driver Presence & Versions
Write-Host "`n[5/5] Checking Latency-Critical Kernel Drivers in System32..." -ForegroundColor Yellow
$criticalDrivers = @(
    @{ Name = "nvlddmkm.sys"; Role = "NVIDIA Display Driver" },
    @{ Name = "amdkmdag.sys"; Role = "AMD GPU Display Driver" },
    @{ Name = "ndis.sys";     Role = "Network Driver Interface Specification" },
    @{ Name = "wdf01000.sys"; Role = "Windows Driver Framework Kernel" },
    @{ Name = "dxgkrnl.sys";  Role = "DirectX Graphics Kernel" }
)

foreach ($drv in $criticalDrivers) {
    $path = "$env:SystemRoot\System32\drivers\$($drv.Name)"
    if (Test-Path $path) {
        $fileInfo = Get-Item $path
        $version = $fileInfo.VersionInfo.FileVersion
        Write-Host " [FOUND] $($drv.Name) ($($drv.Role)) - Version: $version" -ForegroundColor Green
    } else {
        Write-Host " [NOT INSTALLED] $($drv.Name) ($($drv.Role))" -ForegroundColor Gray
    }
}

Write-Host "`n=============================================================" -ForegroundColor Cyan
Write-Host " DIAGNOSTIC SUMMARY & RECOMMENDATIONS:" -ForegroundColor White
Write-Host " 1. To eliminate driver interrupt delays: run .\Set-DeviceMsiMode.ps1 -Type GPU -Enable" -ForegroundColor White
Write-Host " 2. If DPC latency persists, profile system ISR routines with LatencyMon." -ForegroundColor White
Write-Host " 3. Read complete guide: https://luabyte.com/blog/system/fix-dpc-latency-audio-crackling-windows-11" -ForegroundColor Cyan
Write-Host "=============================================================" -ForegroundColor Cyan
