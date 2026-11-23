# DDR5 Sub-Timings Reference & Safe Daily Limits

A technical companion reference to [LuaByte: DDR5 Sub-Timings Tuning Guide](https://luabyte.com/blog/hardware/ddr5-sub-timings-tuning-guide).

---

## 1. DRAM Die Characteristics & Daily Ceilings

| IC Manufacturer & Die | Frequency Target | Primary Sub-Timing Ceiling | Safe Daily VDD |
|---|---|---|---|
| **SK Hynix A-Die** | 6400 to 8000+ MT/s | Lowest tRFC (~120-135 ns), high tREFI | 1.38V - 1.45V |
| **SK Hynix M-Die (24Gb/32Gb)** | 6000 to 7600 MT/s | Balanced tRFC (~140-160 ns), stable IMC | 1.35V - 1.42V |
| **Samsung B-Die (DDR5)** | 5600 to 6200 MT/s | High tRFC requirement (260-300 ns) | 1.30V - 1.38V |
| **Micron A/G-Die** | 5200 to 5600 MT/s | Conservative timings, limited headroom | 1.25V - 1.35V |

---

## 2. Tested Daily Starting Profile (SK Hynix A-Die / M-Die @ 6000-6400 MT/s)

```text
Voltages:
- DRAM VDD:  1.38V - 1.40V
- DRAM VDDQ: 1.38V - 1.40V
- CPU SoC (AMD): 1.20V (Max 1.25V daily)
- CPU VCCSA (Intel): 1.18V - 1.22V

Primary Timings:
- tCL:  30 (at 6000) / 32 (at 6400)
- tRCD: 38
- tRP:  38
- tRAS: 48

Secondary Timings:
- tREFI: 65535 (Requires active airflow / DDR5 PMIC temp < 50°C)
- tRFC1: 440 (at 6000) / 480 (at 6400)
- tRRDS: 4
- tRRDL: 8
- tFAW:  16
- tWR:   48

Tertiary Timings:
- tRDRD_sg: 12
- tRDWR_sg: 16
```

---

## 3. Stability Testing Protocol

1. **Stage 1 (Quick Smoke Test):** TestMem5 with `1usmus_v3.cfg` for 3 cycles (15-20 minutes).
2. **Stage 2 (IMC & Thermal Stress):** Y-Cruncher VST / VT3 test for 30 minutes.
3. **Stage 3 (Final Overnight Soak):** TestMem5 with `configs/tm5-extreme1.cfg` for 3 complete cycles.
