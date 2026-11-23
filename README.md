# Latency Tuning Scripts

Safety-oriented PowerShell automation tools and reference configurations for diagnosing DPC latency jitter, configuring PCI Message Signaled Interrupts (MSI Mode), and validating low-latency memory sub-timings on Windows.

Published by **[LuaByte](https://luabyte.com)** as open-source companions to our low-level Windows systems research.

---

## Technical Guides

Each script in this toolkit directly implements the methodologies analyzed in our engineering articles:

1. **[Configuring MSI Mode in Windows to Reduce Input Lag](https://luabyte.com/blog/system/configure-msi-mode-windows-input-lag)**
   Deep-dive analysis of legacy pin-based line IRQs versus MSI/MSI-X, interrupt priority assignment, and driver-level interrupt latency reduction.
2. **[How to Fix DPC Latency and Audio Crackling in Windows 11](https://luabyte.com/blog/system/fix-dpc-latency-audio-crackling-windows-11)**
   Kernel timer resolution, execution core parking, power plan transitions, and deferred procedure call queue profiling.
3. **[DDR5 Sub-Timings Tuning Guide: Safe Daily Primary and Secondary Timings](https://luabyte.com/blog/hardware/ddr5-sub-timings-tuning-guide)**
   DRAM controller sub-timing rules (tRFC, tREFI, tFAW, turnaround latencies) and memory stress testing protocols.

---

## Safety Guarantees

Modifying Windows hardware interrupt behaviors requires strict safeguards:

- **Elevated Privilege Enforcement**: Scripts immediately halt execution if run without Administrator privileges, preventing partial or corrupt state writes.
- **Automated Pre-Execution Backups**: Before writing any registry value, `Set-DeviceMsiMode.ps1` automatically exports a timestamped `.reg` backup into the `backups/` directory.
- **One-Command Reversion**: If a driver exhibits instability, running `Undo-AllTweaks.ps1` restores the most recent registry backup or resets all device overrides back to native Windows defaults.

---

## Repository Structure

```text
latency-tuning-scripts/
├── backups/               # Automated timestamped registry backup storage (.reg)
├── configs/
│   ├── ddr5-timings-reference.md  # SK Hynix & Samsung DDR5 timing rules and daily ceilings
│   └── tm5-extreme1.cfg           # Memory controller stress-test profile
├── scripts/
│   ├── Set-DeviceMsiMode.ps1      # Safe MSI mode inspector and toggle
│   ├── Test-DpcHealth.ps1         # Windows real-time latency and driver audit
│   └── Undo-AllTweaks.ps1         # Revert utility for restoring previous registry states
└── .github/workflows/
    └── psscriptanalyzer.yml       # Automated PowerShell code quality checks
```

---

## Usage Instructions

Open an **Elevated PowerShell** terminal (`Run as Administrator`) and navigate to the repository directory.

### 1. Inspect Current Device Interrupt Modes

Query all detected PCI Display and USB controllers to view active MSI support and interrupt priority:

```powershell
.\scripts\Set-DeviceMsiMode.ps1 -List
```

### 2. Enable MSI Mode on Graphics Adapters

Enable Message Signaled Interrupts and assign High interrupt priority to all detected GPUs:

```powershell
.\scripts\Set-DeviceMsiMode.ps1 -Type GPU -Enable -Priority High
```

### 3. Enable MSI Mode on USB Host Controllers

Migrate USB controllers (xHCI) to MSI mode to minimize mouse and keyboard polling interrupt jitter:

```powershell
.\scripts\Set-DeviceMsiMode.ps1 -Type USB -Enable
```

> **Note**: A system restart is required for the Windows kernel to reload PCI configuration space and bind MSI interrupt vectors.

### 4. Run Windows Real-Time Latency Diagnostic

Perform a 5-point system diagnostic auditing kernel stopwatch resolution, active power schemes, CPU core parking policies, network interrupt moderation, and latency-sensitive driver files (`nvlddmkm.sys`, `ndis.sys`, `wdf01000.sys`):

```powershell
.\scripts\Test-DpcHealth.ps1
```

### 5. Revert Changes and Restore Registry

Restore the hardware configuration to your latest pre-tweak backup:

```powershell
.\scripts\Undo-AllTweaks.ps1
```

Or target a specific backup file explicitly:

```powershell
.\scripts\Undo-AllTweaks.ps1 -BackupFile .\backups\msi_backup_20261123_120000.reg
```

---

## Memory Tuning Reference

The `configs/` directory contains supplementary resources for memory latency optimization:

- **[DDR5 Sub-Timings Reference](configs/ddr5-timings-reference.md)**: Safe daily voltage boundaries, turnaround timing formulas, and IC-specific profiles for SK Hynix A-die and M-die modules.
- **[TM5 Stress Profile](configs/tm5-extreme1.cfg)**: TestMem5 preset optimized for identifying memory controller instability and temperature-induced DRAM refresh failures.

---

## Contributing

Contributions, bug reports, and hardware compatibility feedback are welcome. Please ensure any script modifications pass the automated PSScriptAnalyzer CI workflow before submitting pull requests.

---

## License

This project is released under the MIT License. Developed and maintained by [LuaByte](https://luabyte.com).
