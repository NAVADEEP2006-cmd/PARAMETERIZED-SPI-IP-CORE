# Parameterized SPI IP Core

A fully synthesizable, technology-independent **SystemVerilog SPI IP Core** featuring:
- **Full-Duplex** SPI communication in all 4 SPI Modes (0, 1, 2, and 3).
- **Independent Master & Synchronous Slave** cores.
- **Configurable Parameters:** `DATA_WIDTH` (8, 16, 32+), `CLOCK_DIVIDER` ($f_{sclk} = f_{clk} / (2D)$), `NUM_SLAVES`, `MISO_SYNC_STAGES`.
- **Integrated QoS / Performance Hardware Counters** for latency, throughput, and error diagnostics.
- **Physical Pad / Loopback Wrapper (`spi_pad_wrapper.sv`)** for seamless SoC integration and verification.
- **Self-Checking Testbench (`spi_tb.sv`)** with automated result reporting and VCD waveforms.
- **Verilator-Ready:** 100% lint-clean with `-Wall` and simulation support.

---

## Directory Structure

```text
spi_ip/
├── rtl/
│   ├── spi_pkg.sv             # Width calculation, mode decode & performance helper functions
│   ├── spi_clock_gen.sv       # SCLK generator & half-period timing engine
│   ├── spi_bit_counter.sv     # Frame bit counter and rollover flag
│   ├── spi_tx_shift.sv        # MSB-first serializer with registered outputs
│   ├── spi_rx_shift.sv        # MSB-first deserializer
│   ├── spi_cs_ctrl.sv         # Active-low chip-select decoder and registers
│   ├── spi_master_fsm.sv      # Master transaction state machine (IDLE..DONE)
│   ├── spi_perf_counters.sv   # QoS / performance monitoring counters
│   ├── spi_master.sv          # Complete SPI master core logic
│   ├── spi_master_top.sv      # Master IP top level with QoS performance hooks
│   ├── spi_top.sv             # Backward-compatibility alias to spi_master_top
│   ├── spi_slave.sv           # Fully synchronous SPI slave with 2-FF synchronizers
│   ├── spi_slave_top.sv       # Slave IP top with tri-state MISO buffer
│   └── spi_pad_wrapper.sv     # Pad layer & Master-Slave loopback integration wrapper
│
├── tb/
│   └── spi_tb.sv              # Comprehensive self-checking verification testbench
│
├── sim/
│   ├── Makefile               # Simulation & lint automation (Verilator, Icarus)
│   ├── sim_main.cpp           # Verilator C++ testbench harness
│   ├── run_sim.py             # Cross-platform simulation and lint script
│   ├── run_sim.ps1            # Native Windows PowerShell runner
│   ├── filelist_rtl.f         # RTL source filelist
│   └── filelist_tb.f          # Testbench filelist
│
├── docs/
│   ├── architecture.md        # Detailed architectural specifications & timing diagrams
│   ├── interface_spec.md      # Pinout and signal contract
│   └── register_parameter_spec.md # Parameters, formulas, and counter specifications
│
└── README.md                  # Project overview and quick start guide
```

---

## Compilation Order

1. **`rtl/spi_pkg.sv`** must be compiled first (defines package constants and functions).
2. The remaining RTL files and testbenches can follow in any order.

---

## IP Integration Guide

### 1. Loopback Verification & System Integration (`spi_pad_wrapper.sv`)
The pad wrapper integrates both the master and slave cores with built-in pull-ups, tri-state pads, and loopback interconnect:

```systemverilog
spi_pad_wrapper #(
  .DATA_WIDTH       (16),
  .CLOCK_DIVIDER    (6),
  .SPI_MODE         (0),
  .NUM_SLAVES       (1),
  .LOOPBACK_MODE    (1'b1)     // 1: internal loopback, 0: external pads
) u_spi_system (
  // Master interface
  .clk              (clk_sys),
  .reset            (rst_sys),
  .start            (spi_start),
  .tx_data          (spi_tx_data),
  .slave_select     (1'b0),
  .rx_data          (spi_rx_data),
  .busy             (spi_busy),
  .done             (spi_done),
  .error            (spi_error),
  .transfer_active  (spi_xfer_active),

  // QoS performance counters
  .perf_clear       (1'b0),
  .perf_txn_count   (),
  .perf_bits_total  (),
  .perf_busy_cycles (),
  .perf_total_cycles(),
  .perf_last_latency(),
  .perf_last_sclk_cycles(),
  .perf_reject_count(),

  // Slave interface
  .clk_slave        (clk_slave),
  .reset_slave      (rst_slave),
  .slave_tx_data    (slv_tx_data),
  .slave_rx_data    (slv_rx_data),
  .slave_rx_valid   (slv_rx_valid),
  .slave_busy       (slv_busy),
  .slave_frame_error(slv_frame_err),

  // External Physical Pads
  .pad_sclk         (SPI_SCLK_PIN),
  .pad_mosi         (SPI_MOSI_PIN),
  .pad_miso         (SPI_MISO_PIN),
  .pad_cs_n         (SPI_CS_N_PIN)
);
```

### 2. Standalone Master Integration (`spi_master_top.sv`)
For designs only requiring the master:

```systemverilog
spi_master_top #(
  .DATA_WIDTH       (8),
  .CLOCK_DIVIDER    (4),
  .SPI_MODE         (0),
  .NUM_SLAVES       (2)
) u_spi_master (
  .clk              (clk),
  .reset            (reset),
  .start            (start),
  .tx_data          (tx_data),
  .slave_select     (slave_select),
  .rx_data          (rx_data),
  .busy             (busy),
  .done             (done),
  .error            (error),
  .transfer_active  (),
  .sclk             (spi_sclk),
  .mosi             (spi_mosi),
  .miso             (spi_miso),
  .cs_n             (spi_cs_n),
  .perf_clear       (1'b0),
  .perf_txn_count   (),
  .perf_bits_total  (),
  .perf_busy_cycles (),
  .perf_total_cycles(),
  .perf_last_latency(),
  .perf_last_sclk_cycles(),
  .perf_reject_count()
);
```

---

## Verification & Simulation

The testbench (`tb/spi_tb.sv`) automatically executes 10 self-checking test suites:
1. **Reset & Idle pin verification** across SPI modes.
2. **Mode 0 Transfer** (CPOL=0, CPHA=0, full duplex).
3. **Mode 1 Transfer** (CPOL=0, CPHA=1, full duplex).
4. **Mode 2 Transfer** (CPOL=1, CPHA=0, full duplex).
5. **Mode 3 Transfer** (CPOL=1, CPHA=1, full duplex).
6. **QoS Performance Verification** comparing measured cycle latency to theoretical formula $2WD + D + 2$.
7. **Error Detection & Rejection** (invalid slave select, start while busy).
8. **Back-to-back streaming transfers** without idle penalty.
9. **16-bit word transfers** (`DATA_WIDTH=16`).
10. **32-bit word transfers** (`DATA_WIDTH=32`).

### Running with Verilator

#### Verilator Lint (Zero Warnings with `-Wall`):
```bash
cd sim
make lint
```
or via Python / PowerShell:
```bash
python run_sim.py lint
# or
powershell ./run_sim.ps1 -Action lint
```

#### Verilator Simulation:
```bash
cd sim
make sim
```
or via Python:
```bash
python run_sim.py sim
```

### Running with Icarus Verilog:
```bash
cd sim
make sim-iverilog
```
or:
```bash
python run_sim.py iverilog
```

Waveforms are automatically dumped to `spi_tb.vcd` and can be inspected in **GTKWave**:
```bash
gtkwave spi_tb.vcd
```
