# Parameterized Synthesizable SystemVerilog SPI IP Core

A modular, parameterized, and fully synthesizable **SystemVerilog SPI IP Core** designed as reusable RTL for digital VLSI, FPGA characterization, and SoC-style integration. The design supports full-duplex SPI communication, configurable timing and data widths, multi-slave selection, loopback verification, and automated simulation/lint flows.

---

## Engineering Highlights

| Verification | Protocol | Parameterization | FPGA Characterization |
|---|---|---|---|
| **16 suites / 74 assertions** | **SPI Modes 0-3** | **8 / 16 / 32-bit verified** | **Artix-7 xc7a35tcsg324-1** |
| Icarus + Verilator + XSim | Full duplex | Multi-slave 1 / 2 / 4 | **39 LUTs / 326 FFs** |
| Verilator lint: **0 warnings / 0 errors** | Registered CS timing | MSB / LSB first | **WNS +15.272 ns @ 50 MHz** |

> **Board validation note:** Physical FPGA board testing was not performed. The reported FPGA results are representative synthesis and implementation results for the specified Artix-7 device.

---

## Key Features

- **Full-Duplex Communication:** Complete protocol support for all 4 SPI Modes:
  - **Mode 0:** `CPOL=0, CPHA=0` (Idle low, sample leading/rising, shift trailing/falling)
  - **Mode 1:** `CPOL=0, CPHA=1` (Idle low, shift leading/rising, sample trailing/falling)
  - **Mode 2:** `CPOL=1, CPHA=0` (Idle high, sample leading/falling, shift trailing/rising)
  - **Mode 3:** `CPOL=1, CPHA=1` (Idle high, shift leading/falling, sample trailing/rising)
- **Parameterized Architecture:**
  - `DATA_WIDTH`: Word width $\ge 1$ bit (verified for 8-bit, 16-bit, and 32-bit transfers).
  - `CLOCK_DIVIDER`: Configurable half-period divider ($f_{sclk} = f_{clk} / (2D)$), enforcing synchronizer safety constraint $D \ge \text{spi\_min\_divider}$.
  - `NUM_SLAVES`: Multi-slave chip-select bus width $\ge 1$ (verified for 1, 2, and 4 slaves with 1-hot mutual exclusion).
  - `LSB_FIRST`: Selectable bit order (`0` = MSB-first, `1` = LSB-first) across master and slave shift paths.
  - `MISO_SYNC_STAGES` & `SLAVE_SYNC_STAGES`: Parameterized flip-flop synchronizers for safe clock-domain crossing and oversampling.
- **Robust Handshake & Error Semantics:**
  - **`busy` / `done` Contract:** `busy` is asserted during active transaction states (`S_SELECT`, `S_TRANSFER`, `S_DESELECT`) and deasserts to `0` during the `S_DONE` pulse cycle.
  - **`done` Pulse:** 1-clock completion pulse; `rx_data` is held stable from the `done` cycle until the next transaction.
  - **Independent Error Flags:** `error` pulses when any transaction request is rejected; `select_error` pulses specifically when rejected due to an invalid slave address (`slave_select >= NUM_SLAVES`).
- **Deterministic CS Timing:**
  - Registered active-low chip select outputs prevent glitches.
  - CS asserts 1 cycle after start is accepted, remains asserted through transfer and done, and deasserts as the core returns to idle (total duration $2WD + D + 1$ cycles).
- **Physical Pad & Loopback Wrapper (`spi_pad_wrapper.sv`):**
  - **`LOOPBACK_MODE = 1`:** Routes master SPI signals to an internal slave (slave index 0) for loopback verification.
  - **`LOOPBACK_MODE = 0`:** Direct external chip pad mode. The internal slave is **not instantiated**, and `pad_miso` is placed in high-impedance (`1'bz`) to eliminate bus contention.
- **Diagnostic / Performance Hardware Counters (`spi_perf_counters.sv`):**
  - 32-bit non-intrusive counters measuring transaction count, total bits, busy cycles, total window cycles, exact transaction latency ($2WD + D + 2$), SCLK active cycles ($2WD$), and rejected start attempts.
- **CI / Simulation Automation:**
  - Automated GitHub Actions workflow with independent jobs for Verilator lint, Icarus Verilog simulation, and Verilator simulation with explicit failure propagation.

---

## Directory Structure

```text
.
├── rtl/
│   ├── spi_pkg.sv             # Mode decode, width helpers, and closed-form performance functions
│   ├── spi_clock_gen.sv       # SCLK generator and half-period tick strobes
│   ├── spi_bit_counter.sv     # Word bit counter and frame completion flag
│   ├── spi_tx_shift.sv        # Transmit shift register (MSB/LSB-first, registered output)
│   ├── spi_rx_shift.sv        # Receive shift register (MSB/LSB-first, safe single-bit handling)
│   ├── spi_cs_ctrl.sv         # Active-low chip-select decoder with registered outputs
│   ├── spi_master_fsm.sv      # Master transaction sequencing FSM (5 states)
│   ├── spi_perf_counters.sv   # Diagnostic and performance measurement telemetry counters
│   ├── spi_master.sv          # Complete SPI master controller
│   ├── spi_master_top.sv      # Master IP top-level with diagnostic telemetry hooks
│   ├── spi_top.sv             # Backward-compatibility alias wrapping spi_master_top
│   ├── spi_slave.sv           # Fully synchronous SPI slave with synchronizers and edge detection
│   ├── spi_slave_top.sv       # Slave IP top-level with tri-state MISO buffer
│   └── spi_pad_wrapper.sv     # SoC integration wrapper (loopback / external pad modes)
│
├── tb/
│   └── spi_tb.sv              # Comprehensive self-checking verification testbench (16 suites / 74 assertions)
│
├── sim/
│   ├── Makefile               # Simulation and lint automation
│   ├── sim_main.cpp           # Verilator C++ testbench harness
│   ├── run_sim.py             # Cross-platform simulation and lint script
│   ├── run_sim.ps1            # Windows PowerShell runner
│   ├── filelist_rtl.f         # RTL source filelist
│   └── filelist_tb.f          # Testbench filelist
│
├── docs/
│   ├── architecture.md        # Detailed block diagrams, state machine, and design decisions
│   ├── interface_spec.md      # Pin contracts, signal timing, and usage guide
│   └── register_parameter_spec.md # Parameters reference and closed-form timing formulas
│
├── .github/workflows/
│   └── spi-ci.yml             # GitHub Actions CI workflow (lint, iverilog, verilator)
│
└── README.md                  # Project overview and documentation
```

---

## Parameters Reference

| Parameter | Default | Valid Range | Scope | Description |
|---|---|---|---|---|
| `DATA_WIDTH` | 8 | $\ge 1$ (1, 8, 16, 32 verified) | Core | Number of bits per transaction. |
| `CLOCK_DIVIDER` | 6 | $\ge \text{spi\_min\_divider}$ ($\ge 6$ for 2 sync stages) | Master | Half-period divider: $f_{sclk} = f_{clk} / (2D)$. Enforces synchronizer latency constraint. |
| `SPI_MODE` | 0 | 0, 1, 2, 3 | Core | SPI mode $\{CPOL, CPHA\}$. |
| `NUM_SLAVES` | 1 | $\ge 1$ (1, 2, 4 verified) | Master | Number of chip select lines on `cs_n`. |
| `MISO_SYNC_STAGES` | 2 | $\ge 1$ | Master | Flop stages for synchronizing incoming MISO. |
| `SLAVE_SYNC_STAGES`| 2 | $\ge 2$ | Slave | Flop stages for synchronizing SCLK, CS_N, MOSI. |
| `LSB_FIRST` | 0 | 0, 1 | Core | `0` = MSB-first, `1` = LSB-first. |
| `ENABLE_PERF` | 1 | 0, 1 | Master | `1` = instantiate telemetry counters; `0` = zero area. |
| `LOOPBACK_MODE` | 1 | 0, 1 | Wrapper | `1` = loopback to slave 0; `0` = external pads (high-Z). |

---

## Timing & Performance Formulas

For word width $W = \text{DATA\_WIDTH}$, divider $D = \text{CLOCK\_DIVIDER}$, and clock frequency $f_{clk}$:

- **SCLK Frequency:** $f_{sclk} = f_{clk} / (2D)$
- **Active SCLK Cycles:** $2 \times W \times D$
- **Total Transaction Latency:** $2WD + D + 2$ system clock cycles (from accepted start through done pulse)
- **Active Busy Cycles:** $2WD + D + 1$ system clock cycles (`busy` deasserts to 0 in the done cycle)
- **Back-to-Back Period:** $2WD + D + 3$ cycles (with start held continuously high)
- **Payload Throughput:** $\frac{f_{clk} \times W}{2WD + D + 3}$ bit/s

*Example ($f_{clk} = 50\text{ MHz}$, $W = 8$, $D = 6$):*
$f_{sclk} = 4.167\text{ MHz}$, latency = $104\text{ cycles}$ ($2.08\ \mu\text{s}$), busy = $103\text{ cycles}$, payload throughput = $3.81\text{ Mbit/s}$.

---

## Verification Suite (`tb/spi_tb.sv`)

The self-checking testbench validates the IP across **16 comprehensive verification suites** executing **74 automated assertions**:
1. **Reset & Idle Pin Verification:** SCLK idle polarity (Modes 0–3), CS_N idle high, busy/done quiescent levels.
2. **SPI Mode 0:** Full-duplex loopback (`CPOL=0, CPHA=0`, 8-bit, MSB-first).
3. **SPI Mode 1:** Full-duplex loopback (`CPOL=0, CPHA=1`, 8-bit, MSB-first).
4. **SPI Mode 2:** Full-duplex loopback (`CPOL=1, CPHA=0`, 8-bit, MSB-first).
5. **SPI Mode 3:** Full-duplex loopback (`CPOL=1, CPHA=1`, 8-bit, MSB-first).
6. **Performance Counters & Telemetry:** Verified measured latency ($104\text{ cycles}$), active SCLK cycles ($96\text{ cycles}$), and deterministic `perf_clear`.
7. **Error Detection & Semantic Separation:** Verified rejection on invalid slave select, separate firing of `error` and `select_error`, and rejected start while busy.
8. **Back-to-Back Consecutive Streaming Transfers:** Verified zero idle cycle penalty when `start` is held continuously asserted across multiple words.
9. **16-Bit Word Transfer:** Verified parameterization for `DATA_WIDTH=16`.
10. **32-Bit Word Transfer:** Verified parameterization for `DATA_WIDTH=32`.
11. **LSB-First Transfer:** Verified bit-reversal and transmission order (`LSB_FIRST=1`).
12. **Multi-Slave CS Verification:** Verified independent 1-hot decoding across 4 chip-select lines (`NUM_SLAVES=4`).
13. **Reset During Active Transaction:** Verified immediate recovery to idle and deassertion of CS upon mid-transfer synchronous reset.
14. **Single-Bit Transfer Boundary:** Verified corner case `DATA_WIDTH=1` for both `1'b1` and `1'b0`.
15. **Clock Divider Minimum Boundary:** Verified exact timing boundary at `CLOCK_DIVIDER=5` (`MISO_SYNC_STAGES=1`).
16. **Reset Lifecycle Verification:** Verified quiescent state during reset assertion before transfer, clean start recovery, and reset after transaction completion.

---

## Tool Verification Status

| Tool / Target | Version | Command | Status | Result / Details |
|---|---|---|---|---|
| **Verilator RTL Lint** | 5.032 | `python sim/run_sim.py lint` | **PASS** | 0 warnings, 0 errors under `-Wall` |
| **Icarus Verilog Sim** | 12.0 | `python sim/run_sim.py iverilog` | **PASS** | 74 / 74 test assertions passed |
| **Verilator Simulation** | 5.032 | `python sim/run_sim.py sim` | **PASS** | 74 / 74 test assertions passed |
| **AMD Vivado XSim** | 2026.1 | `vivado -mode batch -source scripts/vivado/run_vivado.tcl -tclargs -mode sim` | **PASS** | 74 / 74 test assertions passed ($50.491\ \mu\text{s}$) |
| **AMD Vivado Synthesis** | 2026.1 | `vivado -mode batch -source scripts/vivado/run_vivado.tcl -tclargs -mode synth -part xc7a35tcsg324-1` | **PASS** | 39 LUTs, 326 FFs, 0 BRAM, 0 DSP, 0 Latches |
| **AMD Vivado Implementation** | 2026.1 | `vivado -mode batch -source scripts/vivado/run_vivado.tcl -tclargs -mode impl -part xc7a35tcsg324-1` | **PASS** | Routed cleanly: WNS = +15.272 ns, WHS = +0.170 ns |

---

## FPGA Implementation & Timing Results

* **Primary Synthesis Top:** `spi_master_top` (Out-of-Context IP Core)
* **Target FPGA Device:** AMD Artix-7 `xc7a35tcsg324-1` (Representative FPGA target for synthesis & implementation analysis)
* **Physical Board Validation:** **Not performed** (RTL / IP-core verification project; no board hardware claims made)
* **Core Clock Constraint:** 50.000 MHz ($T = 20.000\text{ ns}$, 50% duty cycle, defined in `constraints/spi_master_top.xdc`)

### Resource Utilization (`xc7a35tcsg324-1`)

| Resource | Used | Available | Utilization (%) | Notes |
|---|---|---|---|---|
| **Slice LUTs** | 39 | 20,800 | 0.19% | Fully logic LUTs (0 LUTRAM / SRL) |
| **Slice Registers (FF)** | 326 | 41,600 | 0.78% | 325 FDRE, 1 FDSE |
| **Registers as Latch** | 0 | 41,600 | **0.00%** | Zero latches inferred |
| **Slices** | 84 | 8,150 | 1.03% | 43 SLICEL, 41 SLICEM |
| **Block RAM (Tile)** | 0 | 50 | 0.00% | No BRAM utilized |
| **DSP48E1** | 0 | 90 | 0.00% | No DSPs utilized |
| **Bonded IOB** | 0 | 210 | 0.00% | Out-of-Context synthesis mode |
| **Clock Buffers (BUFG)**| 0 | 32 | 0.00% | Out-of-Context core netlist |

### Post-Routing Timing Closure Summary

| Metric | Result | Target / Requirement | Status |
|---|---|---|---|
| **Worst Negative Slack (WNS)** | **+15.272 ns** | $\ge 0.000\text{ ns}$ | **MET** |
| **Total Negative Slack (TNS)** | **0.000 ns** | $0.000\text{ ns}$ (0 / 641 failing endpoints) | **MET** |
| **Worst Hold Slack (WHS)** | **+0.170 ns** | $\ge 0.000\text{ ns}$ | **MET** |
| **Total Hold Slack (THS)** | **0.000 ns** | $0.000\text{ ns}$ (0 / 641 failing endpoints) | **MET** |
| **Worst Pulse Width Slack (WPWS)** | **+9.500 ns** | $\ge 0.000\text{ ns}$ | **MET** |
| **Critical Path Delay** | 3.918 ns (Logic: 0.744 ns, Route: 3.174 ns) | Max Period: 20.000 ns | **MET** |
| **Design Rule Check (DRC)** | 0 Errors, 0 Critical Warnings, 1 Advisory Warning (CFGBVS-1) | Clean | **PASS** |

*All reports archived in `reports/vivado/`.*

---

## Quick Start (Vivado, Simulation & Lint)

### AMD Vivado Automation Flow
Run the reproducible batch Tcl flow from the project root:
```bash
# 1. Non-device-specific RTL Elaboration & AST Analysis
vivado -mode batch -notrace -source scripts/vivado/run_vivado.tcl -tclargs -mode elaborate -top spi_master_top

# 2. Complete Synthesis & Implementation Flow (Artix-7 xc7a35tcsg324-1)
vivado -mode batch -notrace -source scripts/vivado/run_vivado.tcl -tclargs -mode impl -top spi_master_top -part xc7a35tcsg324-1

# 3. AMD Vivado XSim Functional Simulation
vivado -mode batch -notrace -source scripts/vivado/run_vivado.tcl -tclargs -mode sim
```

### Verilator Lint
```bash
python sim/run_sim.py lint
# or using Makefile:
make -C sim lint
```

### Icarus Verilog Simulation
```bash
python sim/run_sim.py iverilog
# or using Makefile:
make -C sim sim-iverilog
```

### Verilator Simulation
```bash
python sim/run_sim.py sim
# or using Makefile:
make -C sim sim
```

### Waveform Inspection
Waveforms are dumped to `sim/spi_tb.vcd` and can be viewed using GTKWave:
```bash
gtkwave sim/spi_tb.vcd
```

