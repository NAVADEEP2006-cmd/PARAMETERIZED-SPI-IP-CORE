# Interface Specification (`spi_master_top` / `spi_top`)

## 1. Master System-Side Interface
| Signal | Direction | Width | Description |
|---|---|---|---|
| `clk` | Input | 1 | Master system clock |
| `reset` | Input | 1 | Synchronous, active-high reset |
| `start` | Input | 1 | Transaction request. Accepted when `busy=0` and `slave_select < NUM_SLAVES`. Level-sensitive: held high repeats transactions back-to-back. Ignored while `busy=1`. |
| `tx_data` | Input | `DATA_WIDTH` | Transmit payload; sampled into shift register on the cycle `start` is accepted. |
| `slave_select` | Input | `clog2_safe(NUM_SLAVES)` | Binary slave index (0 to `NUM_SLAVES-1`). Sampled on accepted start. Tied to `1'b0` when `NUM_SLAVES=1`. |
| `rx_data` | Output | `DATA_WIDTH` | Received word. Captured in `S_DESELECT`, valid during `done` cycle, and held until next transaction capture. |
| `busy` | Output | 1 | Active transaction indicator. High during `S_SELECT`, `S_TRANSFER`, and `S_DESELECT`. **Low during the `done` pulse cycle (`S_DONE`)**. |
| `done` | Output | 1 | One-clock completion pulse indicating transaction complete and `rx_data` is valid. |
| `error` | Output | 1 | One-clock pulse when a rising-edge `start` is rejected for **any** reason (`busy=1` OR `slave_select >= NUM_SLAVES`). |
| `select_error` | Output | 1 | One-clock pulse when a rising-edge `start` is rejected **specifically because `slave_select >= NUM_SLAVES`** (will not fire if rejected solely due to `busy=1`). |
| `transfer_active` | Output | 1 | High while SCLK is actively toggling (`S_TRANSFER` state). |

### Master Usage Contract
1. Apply `tx_data` and `slave_select`.
2. Assert `start` for 1 clock cycle (or hold high for continuous back-to-back streaming).
3. Wait for `done` assertion (1 clock pulse).
4. Read `rx_data` in or after the `done` cycle.
5. If `start` is asserted while `busy=1`, `error` pulses for 1 cycle and the request is ignored without interrupting the active transaction.
6. If `start` is asserted with `slave_select >= NUM_SLAVES`, both `error` and `select_error` pulse for 1 cycle and the transaction is rejected.

---

## 2. Master SPI Physical Pins
| Signal | Direction | Width | Description |
|---|---|---|---|
| `sclk` | Output | 1 | SPI serial clock. Idle level = `CPOL`. Toggles only during active transfer (`2*DATA_WIDTH` edges). |
| `mosi` | Output | 1 | Master-Out Slave-In serial data. Registered output. Glitch-free. |
| `miso` | Input | 1 | Master-In Slave-Out serial data. Sampled through `MISO_SYNC_STAGES` flops. |
| `cs_n` | Output | `NUM_SLAVES` | Active-low chip select bus. Glitch-free registered outputs. At most one bit is low at any time. |

### CS Timing & Release Contract
- **Assertion:** `cs_n[slave_select]` asserts LOW 1 system clock cycle after `start` is accepted (at entry to `S_TRANSFER`).
- **Hold:** `cs_n` remains LOW throughout `S_TRANSFER` (`2*DATA_WIDTH*CLOCK_DIVIDER` cycles), `S_DESELECT` (`CLOCK_DIVIDER` cycles), and `S_DONE` (1 cycle).
- **Deassertion:** `cs_n` deasserts HIGH on the transition from `S_DONE` to `S_IDLE`. Total CS active duration = `2*W*D + D + 1` cycles.

---

## 3. Performance / Diagnostic Telemetry (`ENABLE_PERF=1`)
All counters are 32-bit, free-running, wrap on overflow, and clear synchronously to 0 on `perf_clear` or `reset`:
| Signal | Direction | Width | Description |
|---|---|---|---|
| `perf_clear` | Input | 1 | Synchronous clear for all performance counters. |
| `perf_txn_count` | Output | 32 | Total completed transactions (`done` pulses). |
| `perf_bits_total` | Output | 32 | Total bits transferred (`txn_count * DATA_WIDTH`). |
| `perf_busy_cycles` | Output | 32 | Total system clock cycles with `busy=1`. |
| `perf_total_cycles` | Output | 32 | Total clock cycles since reset or last `perf_clear`. |
| `perf_last_latency` | Output | 32 | Total latency of last transaction from `S_SELECT` through `S_DONE` ($2WD + D + 2$). |
| `perf_last_sclk_cycles`| Output | 32 | Cycles SCLK was actively toggling in last transaction ($2WD$). |
| `perf_reject_count` | Output | 32 | Total rejected transaction attempts (`error` pulses). |

---

## 4. Slave System-Side Interface (`spi_slave` / `spi_slave_top`)
| Signal | Direction | Width | Description |
|---|---|---|---|
| `clk` | Input | 1 | Local slave clock (must oversample SCLK by $\ge 4\times$). |
| `reset` | Input | 1 | Synchronous, active-high reset. |
| `tx_data` | Input | `DATA_WIDTH` | Transmit word, latched into slave shift register on falling edge of `cs_n`. |
| `rx_data` | Output | `DATA_WIDTH` | Received word. Updated when full frame completes. |
| `rx_valid` | Output | 1 | One-clock pulse indicating new valid `rx_data`. |
| `busy` | Output | 1 | Slave active indicator (asserted while synchronized `cs_n` is low). |
| `frame_error` | Output | 1 | One-clock pulse on CS rising edge if frame was aborted early ($0 < \text{bits} < W$) or extra SCLK edges occurred ($> W$). |
| `miso_o` | Output | 1 | Serial MISO data out (before tri-state buffer). |
| `miso_oe` | Output | 1 | MISO output drive enable (asserted when slave is selected). |
| `pad_miso` | Inout | 1 | Physical tri-state pin (`spi_slave_top` / `spi_pad_wrapper`). High-Z when unselected. |

---

## 5. Integration Wrapper Modes (`spi_pad_wrapper.sv`)
- **`LOOPBACK_MODE = 1`:** Internal loopback between master and slave 0. Master `cs_n[0]` drives internal slave `cs_n`. Master `cs_n[1..NUM_SLAVES-1]` drive external pads for peripheral expansion. `pad_miso` is driven by slave 0 tri-state buffer.
- **`LOOPBACK_MODE = 0`:** Pure external pad mode. Master connects directly to chip pins (`pad_sclk`, `pad_mosi`, `pad_cs_n`). Internal slave is **not instantiated** and `pad_miso` is **tri-stated to high-Z** (`1'bz`) to eliminate any contention with external SPI peripherals.

---

## 6. Timing & Constraint Specification

- **Constraint File:** `constraints/spi_master_top.xdc`
- **Primary Core Clock:**
  ```xdc
  create_clock -period 20.000 -name clk -waveform {0.000 10.000} [get_ports clk]
  ```
- **Clock Frequency Target:** 50.000 MHz ($T = 20.000\text{ ns}$, 50% duty cycle).
- **Scope:** Defines the IP-level synchronous clock budget. Board-specific physical pin mappings and I/O standards are to be defined when integrating into a physical board.
- **Representative FPGA Synthesis Target:** AMD Artix-7 `xc7a35tcsg324-1` (Out-of-Context).
- **Physical Board Validation:** **Not performed** (RTL / IP-core verification project).

