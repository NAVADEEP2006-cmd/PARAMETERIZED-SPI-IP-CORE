# Parameters and Performance Specification

The SPI IP Core is configured through SystemVerilog parameters and controlled directly via system-side handshaking signals.

---

## 1. Parameters Reference

| Parameter | Default | Valid Range | Scope | Description |
|---|---|---|---|---|
| `DATA_WIDTH` (W) | 8 | $\ge 1$ (1, 8, 16, 32 verified) | Master & Slave | Width of the transfer word in bits; sizes shift registers, data buses, and bit counter. |
| `CLOCK_DIVIDER` (D) | 6 | $\ge \text{spi\_min\_divider}$ ($\ge 6$ for 2 sync stages) | Master & Top | Half-period divider: $f_{sclk} = f_{clk} / (2D)$. Enforces loopback round-trip synchronizer latency. |
| `SPI_MODE` | 0 | 0, 1, 2, 3 | Master & Slave | SPI mode configuration: `Mode = {CPOL, CPHA}`. Controls clock polarity and phase. |
| `NUM_SLAVES` | 1 | $\ge 1$ (1, 2, 4 verified) | Master & Top | Number of independent chip-select lines on the `cs_n` bus. |
| `MISO_SYNC_STAGES` | 2 | $\ge 1$ | Master | Number of flip-flop synchronizer stages on the incoming `miso` line. |
| `SLAVE_SYNC_STAGES`| 2 | $\ge 2$ | Slave | Number of flip-flop synchronizer stages for `sclk`, `cs_n`, and `mosi`. |
| `LSB_FIRST` | 0 | 0, 1 | Master & Slave | Bit ordering: `0` = MSB-first (bit[W-1] first); `1` = LSB-first (bit[0] first). |
| `ENABLE_PERF` | 1 | 0, 1 | Master & Top | `1` = instantiate 32-bit hardware diagnostic counters; `0` = tie outputs to 0 (zero area). |
| `LOOPBACK_MODE` | 1 | 0, 1 | Pad Wrapper | `1` = loopback to internal slave 0; `0` = external pad mode (`pad_miso` tri-stated). |

---

## 2. Timing Analysis & Cycle Breakdown

Let $W = \text{DATA\_WIDTH}$, $D = \text{CLOCK\_DIVIDER}$, and $f_{clk}$ be the system clock frequency.

### FSM State Durations
1. **`S_IDLE`:** Waiting for transaction request.
2. **`S_SELECT`:** Exactly **1 cycle**. `busy=1`. Chip select `cs_n` is registered and goes LOW at the end of this cycle.
3. **`S_TRANSFER`:** Exactly **$2 \times W \times D$ cycles**. `busy=1`. Serial clock `sclk` toggles $2W$ times (half-period = $D$ cycles).
4. **`S_DESELECT`:** Exactly **$D$ cycles**. `busy=1`. `sclk` is held idle for one half-period. On the final cycle, RX data is captured into the holding register.
5. **`S_DONE`:** Exactly **1 cycle**. **`busy=0`, `done=1`**. `cs_n` deasserts HIGH at the end of this cycle.

### Performance Formulas
| Metric | Closed-Form Formula | Notes |
|---|---|---|
| SCLK Frequency ($f_{sclk}$) | $f_{clk} / (2D)$ | Master SCLK rate |
| SCLK Active Cycles | $2 \times W \times D$ | Cycles `transfer_active == 1` |
| Latency Overhead | $D + 2$ cycles | CS setup (1) + CS hold ($D$) + Done pulse (1) |
| **Transaction Latency** | $2WD + D + 2$ cycles | Cycles from accepted `start` through `done` pulse inclusive |
| **Active Busy Cycles** | $2WD + D + 1$ cycles | Cycles where `busy == 1` (`busy` is 0 during `done`) |
| Back-to-Back Period | $2WD + D + 3$ cycles | Latency + 1 turnaround cycle between transactions |
| Back-to-Back Throughput | $\frac{f_{clk} \times W}{2WD + D + 3}$ bit/s | Net payload data rate |
| Protocol Efficiency | $\frac{2WD}{2WD + D + 3}$ | Active SCLK time vs total back-to-back period |

### Numerical Example ($f_{clk} = 50\text{ MHz}$, $W = 8$, $D = 6$)
- $f_{sclk} = 50\text{ MHz} / (2 \times 6) = 4.167\text{ MHz}$
- SCLK Active Cycles: $2 \times 8 \times 6 = 96\text{ cycles}$ ($1.92\ \mu\text{s}$)
- Active Busy Cycles: $96 + 6 + 1 = 103\text{ cycles}$ ($2.06\ \mu\text{s}$)
- Transaction Latency: $96 + 6 + 2 = 104\text{ cycles}$ ($2.08\ \mu\text{s}$)
- Back-to-Back Throughput: $50 \times 10^6 \times 8 / 105 \approx 3.81\text{ Mbit/s}$
- Protocol Efficiency: $96 / 105 \approx 91.4\%$

---

## 3. Diagnostic & Performance Telemetry (`perf_*`)

The core provides comprehensive non-intrusive diagnostic counters. These are telemetry hooks, not quality-of-service (QoS) arbiters.

| Output | Type | Formula / Semantic | Verification Match |
|---|---|---|---|
| `perf_txn_count` | 32-bit uint | Count of completed transactions (`done` pulses) | Verified |
| `perf_bits_total` | 32-bit uint | `txn_count * DATA_WIDTH` | Verified |
| `perf_busy_cycles` | 32-bit uint | Cumulative cycles where `busy == 1` | Verified |
| `perf_total_cycles`| 32-bit uint | Free-running cycle counter since reset/clear | Verified |
| `perf_last_latency`| 32-bit uint | Latency of the most recent transaction ($2WD + D + 2$) | Verified (104 cycles for W=8, D=6) |
| `perf_last_sclk_cycles`| 32-bit uint | SCLK active toggling duration of last transaction ($2WD$) | Verified (96 cycles for W=8, D=6) |
| `perf_reject_count`| 32-bit uint | Count of rejected start attempts (`error` pulses) | Verified |

---

## 4. Hardware Synthesis & Resource Cost Profile

Synthesis and implementation verified on representative FPGA target **AMD Artix-7 `xc7a35tcsg324-1`** using AMD Vivado v2026.1 in out-of-context mode:

| Resource | Count | Device Capacity | Utilization | Notes |
|---|---|---|---|---|
| **Slice LUTs** | 39 | 20,800 | 0.19% | Pure logic LUTs (0 distributed RAM / SRL) |
| **Slice Registers** | 326 | 41,600 | 0.78% | 325 FDRE, 1 FDSE; **0 Latches** |
| **Slices** | 84 | 8,150 | 1.03% | 43 SLICEL, 41 SLICEM |
| **BRAM Tiles** | 0 | 50 | 0.00% | No block memory consumed |
| **DSP48E1** | 0 | 90 | 0.00% | No DSP blocks consumed |

*Note: The core clock constraint is 50.000 MHz (20.000 ns period). Physical board validation was not performed (RTL/IP-core verification project).*

