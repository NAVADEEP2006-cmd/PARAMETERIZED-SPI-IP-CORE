# Design Specification

## 1. Top-Level Interface Signals

### 1.1 Master Host System Interface (`spi_master_top` / `spi_master`)

| Signal Name | Direction | Bit Width | Type | Description |
|---|:---:|:---:|:---:|---|
| `clk` | Input | 1 | Clock | Master core synchronous system clock. |
| `reset` | Input | 1 | Control | Synchronous, active-high master reset. |
| `start` | Input | 1 | Control | Transaction initiation request. Accepted when `busy=0` and `slave_select` is valid. Holding high enables continuous back-to-back streaming. |
| `tx_data` | Input | `DATA_WIDTH` | Data | Transmit data payload; latched into TX shift register on accepted start. |
| `slave_select` | Input | $\lceil\log_2(\text{NUM\_SLAVES})\rceil$ | Control | Binary peripheral index ($0$ to $\text{NUM\_SLAVES}-1$). Tied to `1'b0` when `NUM_SLAVES=1`. |
| `rx_data` | Output | `DATA_WIDTH` | Data | Deserialized receive word; captured during `S_DESELECT`, valid during `done`, held stable until next transaction completion. |
| `busy` | Output | 1 | Status | Transaction active indicator. High during `S_SELECT`, `S_TRANSFER`, and `S_DESELECT`. **Deasserts to 0 during the `done` cycle (`S_DONE`)**. |
| `done` | Output | 1 | Status | One-cycle active-high completion strobe indicating `rx_data` is valid. |
| `error` | Output | 1 | Status | One-cycle active-high pulse fired on rising edge of `start` if request is rejected for **any** reason (`busy=1` or invalid `slave_select`). |
| `select_error` | Output | 1 | Status | One-cycle active-high pulse fired on rising edge of `start` **only** if rejected due to invalid slave index (`slave_select >= NUM_SLAVES`). |
| `transfer_active` | Output | 1 | Status | High exclusively while SCLK is actively toggling (`S_TRANSFER` state). |
| `txn_accept` | Output | 1 | Status | Internal/diagnostic strobe pulsing high for 1 cycle when `start` is accepted. |

### 1.2 Master Physical SPI Bus Interface

| Signal Name | Direction | Bit Width | Type | Description |
|---|:---:|:---:|:---:|---|
| `sclk` | Output | 1 | Clock | Serial clock driven to peripherals. Quiescent level determined by `CPOL`. |
| `mosi` | Output | 1 | Serial Data | Master-Out Slave-In serial data. Registered output; glitch-free. |
| `miso` | Input | 1 | Serial Data | Master-In Slave-Out serial data. Synchronized through `MISO_SYNC_STAGES` flip-flops. |
| `cs_n` | Output | `NUM_SLAVES` | Control | Active-low chip-select bus. Glitch-free registered outputs. Exactly one bit asserted low during transfer. |

### 1.3 Telemetry & Diagnostic Interface (`ENABLE_PERF=1`)

| Signal Name | Direction | Bit Width | Type | Description |
|---|:---:|:---:|:---:|---|
| `perf_clear` | Input | 1 | Control | Synchronous clear for all telemetry counters. |
| `perf_txn_count` | Output | 32 | Metric | Cumulative completed transactions (`done` pulses). |
| `perf_bits_total` | Output | 32 | Metric | Cumulative transferred payload bits ($N_{txn} \times \text{DATA\_WIDTH}$). |
| `perf_busy_cycles` | Output | 32 | Metric | Cumulative clock cycles with `busy=1`. |
| `perf_total_cycles` | Output | 32 | Metric | Free-running clock cycle counter since reset or `perf_clear`. |
| `perf_last_latency` | Output | 32 | Metric | Exact cycle latency of the last completed transaction ($2WD + D + 2$). |
| `perf_last_sclk_cycles` | Output | 32 | Metric | Active SCLK toggling duration of the last transaction ($2WD$). |
| `perf_reject_count` | Output | 32 | Metric | Cumulative rejected transaction requests (`error` pulses). |

### 1.4 Slave System-Side Interface (`spi_slave` / `spi_slave_top`)

| Signal Name | Direction | Bit Width | Type | Description |
|---|:---:|:---:|:---:|---|
| `clk` | Input | 1 | Clock | Local slave synchronous clock (must oversample SCLK by $\ge 4\times$). |
| `reset` | Input | 1 | Control | Synchronous active-high reset. |
| `tx_data` | Input | `DATA_WIDTH` | Data | Transmit data payload; latched into shift register on falling edge of `cs_n`. |
| `rx_data` | Output | `DATA_WIDTH` | Data | Received data word; updated upon full frame reception. |
| `rx_valid` | Output | 1 | Status | One-cycle active-high pulse indicating new valid `rx_data`. |
| `busy` | Output | 1 | Status | High while synchronized `cs_n` is asserted low. |
| `frame_error` | Output | 1 | Status | One-cycle pulse upon `cs_n` rising edge if frame was aborted early ($0 < \text{bits} < W$) or extra SCLK edges occurred ($> W$). |
| `miso_o` | Output | 1 | Data | Serial MISO data out (before tri-state buffer). |
| `miso_oe` | Output | 1 | Control | MISO output drive enable (asserted while slave is selected). |
| `pad_miso` | Inout | 1 | Physical Pin | Physical tri-state pin (`spi_slave_top`). Driven when selected, high-Z when unselected. |

---

## 2. Configuration Parameters

| Parameter | Type | Default | Valid Range | Scope | Description |
|---|:---:|:---:|:---:|:---:|---|
| `DATA_WIDTH` ($W$) | `int` | 8 | $\ge 1$ | Master & Slave | Number of bits per transaction frame. Verified for 1, 8, 16, and 32 bits. |
| `CLOCK_DIVIDER` ($D$) | `int` | 6 | $\ge \text{spi\_min\_divider}$ | Master & Top | Half-period division factor ($f_{sclk} = f_{clk} / (2D)$). Must satisfy synchronizer safety. |
| `SPI_MODE` | `int` | 0 | $0, 1, 2, 3$ | Master & Slave | Operating mode encoding: $\{CPOL, CPHA\}$. |
| `NUM_SLAVES` | `int` | 1 | $\ge 1$ | Master & Top | Width of `cs_n` active-low chip select bus. Verified for 1, 2, and 4 slaves. |
| `MISO_SYNC_STAGES` | `int` | 2 | $\ge 1$ | Master | Number of flip-flop synchronizer stages on incoming `miso` line. |
| `SLAVE_SYNC_STAGES` | `int` | 2 | $\ge 2$ | Slave | Number of flip-flop synchronizer stages for incoming `sclk`, `cs_n`, and `mosi`. |
| `LSB_FIRST` | `bit` | `1'b0` | $0, 1$ | Master & Slave | Bit transmission order: `0` = MSB-first (bit $[W-1]$ first); `1` = LSB-first (bit $[0]$ first). |
| `ENABLE_PERF` | `bit` | `1'b1` | $0, 1$ | Master & Top | Instantiation gate for 32-bit hardware diagnostic telemetry counters. |
| `LOOPBACK_MODE` | `bit` | `1'b1` | $0, 1$ | Pad Wrapper | `1` = internal loopback to slave 0; `0` = external chip pad mode (`pad_miso` high-Z). |

---

## 3. Clocking, Reset, and Timing Rules

### 3.1 Reset Strategy
- **Reset Polarity:** Active-high synchronous reset (`reset`).
- **Reset Action:** All state machines transition to `S_IDLE`, shift registers clear to zero, `sclk` returns to `CPOL`, and `cs_n` deasserts to all-ones (`1'b1`).
- **Mid-Transaction Reset:** Asserting `reset` during active serial transfer immediately aborts transmission, drops `busy`, and deasserts chip select within 1 clock cycle without generating false `done` pulses.

### 3.2 Clocking Constraints
- **Master Clock Domain:** Single synchronous clock `clk`. No derived, gated, or internally generated ripple clocks are used for sequential logic.
- **Slave Oversampling Constraint:** The slave operates on a local clock `clk` oversampling the SPI bus:
  $$f_{clk\_slave} \ge 4 \times f_{sclk}$$
- **Loopback Minimum Divider:** In master-slave loopback configurations, round-trip delay through input synchronizers, edge detectors, output registers, and master synchronizers imposes the constraint:
  $$D \ge \text{MISO\_SYNC\_STAGES} + 4$$
  For `MISO_SYNC_STAGES = 2`, the minimum legal divider is $D = 6$.

---

## 4. Transaction Cycle Timing & Closed-Form Equations

Let $W = \text{DATA\_WIDTH}$, $D = \text{CLOCK\_DIVIDER}$, and $f_{clk}$ be the core clock frequency.

| Metric | Formula | Value ($W=8, D=6, f_{clk}=50\text{ MHz}$) | Notes |
|---|:---:|:---:|---|
| SCLK Frequency ($f_{sclk}$) | $\frac{f_{clk}}{2D}$ | $4.167\text{ MHz}$ | Master SCLK rate |
| SCLK Active Cycles | $2 \times W \times D$ | $96\text{ cycles}$ ($1.92\ \mu\text{s}$) | Cycles with SCLK actively toggling |
| Latency Overhead | $D + 2$ | $8\text{ cycles}$ ($0.16\ \mu\text{s}$) | CS setup ($1$) + CS hold ($D$) + Done pulse ($1$) |
| **Total Transaction Latency** | $2WD + D + 2$ | **$104\text{ cycles}$ ($2.08\ \mu\text{s}$)** | From accepted `start` through `done` cycle |
| **Active Busy Cycles** | $2WD + D + 1$ | **$103\text{ cycles}$ ($2.06\ \mu\text{s}$)** | Cycles `busy=1` (`busy=0` during `done`) |
| Back-to-Back Period | $2WD + D + 3$ | $105\text{ cycles}$ ($2.10\ \mu\text{s}$) | Continuous streaming period |
| Back-to-Back Throughput | $\frac{f_{clk} \times W}{2WD + D + 3}$ | $3.81\text{ Mbit/s}$ | Net data transfer payload rate |
| Protocol Bus Efficiency | $\frac{2WD}{2WD + D + 3}$ | $91.43\%$ | Ratio of active SCLK time to total transaction period |

---

## 5. Handshake Contracts & State Sequencing

```text
State       | IDLE ──► SELECT ──► TRANSFER ──► DESELECT ──► DONE ──► IDLE
Cycle       | 0    │   1      │   2..2WD+1 │   2WD+2..  │   2WD+D+2│ 2WD+D+3
cs_active   | 0    │   1      │   1        │   1        │   0      │ 0
cs_n[sel]   | 1    │   1      │   0        │   0        │   0      │ 1
sclk        | CPOL │   CPOL   │   toggling │   CPOL     │   CPOL   │ CPOL
busy        | 0    │   1      │   1        │   1        │   0      │ 0
done        | 0    │   0      │   0        │   0        │   1      │ 0
capture     | 0    │   0      │   0        │   tick     │   0      │ 0
```

1. **Request Acceptance:** `start` is sampled in `S_IDLE`. If `slave_select < NUM_SLAVES`, the core accepts the request, latches `tx_data` and `slave_select`, and transitions to `S_SELECT`.
2. **Chip-Select Setup:** `S_SELECT` asserts `cs_active`. Registered `cs_n[slave_select]` falls low at the next clock edge.
3. **Serial Transfer:** `S_TRANSFER` executes for exactly $2WD$ cycles. Data is shifted and sampled according to configured `SPI_MODE` and `LSB_FIRST`.
4. **Hold & Capture:** `S_DESELECT` holds CS low for $D$ cycles after SCLK returns to `CPOL`. On the final cycle, `capture` latches deserialized data into `rx_data`.
5. **Completion Pulse:** `S_DONE` pulses `done=1` with `busy=0`. `cs_active=0` releases `cs_n` high on the transition back to `S_IDLE`.

---

## 6. Implementation Status Distinction

> [!IMPORTANT]
> The specifications in Sections 1 through 5 describe **verified, implemented RTL functionality**. Features associated with the autonomous multi-device scheduler (descriptor queues, deadline tracking, DMA bridging) are planned extensions and are not implemented in this baseline.
