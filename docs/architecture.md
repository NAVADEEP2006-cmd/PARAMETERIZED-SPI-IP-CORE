# Architecture Specification

## 1. System Block Diagram

```text
Host Logic
  ├── start, tx_data, slave_select ───────► [ spi_master ] ────────► sclk, mosi, cs_n[N-1:0]
  ◄── rx_data, busy, done, error, sel_err ─ [            ] ◄──────── miso
                                            │
                                            ├── spi_master_fsm    (5-state control engine)
                                            ├── spi_clock_gen     (SCLK divider & edge generator)
                                            ├── spi_tx_shift      (registered serializer: MSB/LSB)
                                            ├── spi_rx_shift      (deserializer: MSB/LSB)
                                            ├── spi_bit_counter   (word bit counter & completion flag)
                                            ├── spi_cs_ctrl       (active-low registered CS decoder)
                                            └── miso_sr           (MISO synchronizer flip-flops)

Diagnostic / Telemetry Extension:
  [ spi_master ] + [ spi_perf_counters ] ──► spi_master_top (or compatibility alias spi_top)

Physical Pad & Integration Wrapper:
  [ spi_master_top ] ──► [ spi_pad_wrapper ] ──► Physical Pins (pad_sclk, pad_mosi, pad_cs_n, pad_miso)
                                │
                          LOOPBACK_MODE:
                            1: Internal loopback to slave 0 (pad_miso driven by slave)
                            0: Pure external pad mode (pad_miso high-Z, no internal slave)
```

---

## 2. Key Architectural Decisions

- **Synchronous, Active-High Reset:** Single reset strategy across master, slave, and wrappers. Guarantees deterministic state entry, eliminates asynchronous recovery/removal hazards, and maps directly to FPGA/ASIC standard cell libraries.
- **Single Clock Domain per Core:** The master operates strictly in its local `clk` domain. The slave operates synchronously in its own local `clk` domain and oversamples asynchronous SPI signals (`sclk`, `cs_n`, `mosi`) through multi-stage flip-flop synchronizers (`SLAVE_SYNC_STAGES >= 2`). No derived or gated clocks are used.
- **SPI Mode Encoding:** Mode is parameterized as `SPI_MODE` $\in \{0, 1, 2, 3\}$, where $\text{Mode} = \{\text{CPOL}, \text{CPHA}\}$.
  - Mode 0: `CPOL=0, CPHA=0` (Idle low, sample leading/rising, shift trailing/falling)
  - Mode 1: `CPOL=0, CPHA=1` (Idle low, shift leading/rising, sample trailing/falling)
  - Mode 2: `CPOL=1, CPHA=0` (Idle high, sample leading/falling, shift trailing/rising)
  - Mode 3: `CPOL=1, CPHA=1` (Idle high, shift leading/falling, sample trailing/rising)
- **Parameterized Bit Ordering (`LSB_FIRST`):**
  - `LSB_FIRST = 0`: MSB-first. Bit $[W-1]$ is transferred first; RX shifts left.
  - `LSB_FIRST = 1`: LSB-first. Bit $[0]$ is transferred first; RX shifts right.
  - Implemented cleanly within the shift registers without datapath duplication.
- **Strict `busy` and `done` Handshake Contract:**
  - `busy` is asserted during active transaction execution (`S_SELECT`, `S_TRANSFER`, `S_DESELECT`).
  - **`busy` deasserts to 0 in the `S_DONE` pulse cycle.**
  - `done` pulses HIGH for exactly 1 clock cycle in `S_DONE`.
  - `rx_data` is captured in `S_DESELECT`, is valid during `S_DONE`, and holds its value until the next transaction completion.
- **Independent Error vs Select Error Semantics:**
  - `error` pulses HIGH for 1 cycle when a rising-edge `start` request is rejected for **any** reason (`busy=1` or `slave_select >= NUM_SLAVES`).
  - `select_error` pulses HIGH for 1 cycle **only when rejected due to an invalid slave address** (`slave_select >= NUM_SLAVES`). A busy rejection does not assert `select_error`.
- **Deterministic CS Timing & Release:**
  - `cs_n` is registered to guarantee glitch-free operation.
  - Asserts LOW at the start of `S_TRANSFER` (1 cycle after `start` is accepted).
  - Remains LOW across `S_TRANSFER`, `S_DESELECT`, and `S_DONE`.
  - Deasserts HIGH on the transition from `S_DONE` back to `S_IDLE`.
- **External vs Loopback Mode Contention Elimination:**
  - In `LOOPBACK_MODE = 1`: Master connects to internal slave 0; `pad_miso` is driven by the slave tri-state driver.
  - In `LOOPBACK_MODE = 0`: Master connects exclusively to external chip pads. The internal slave is **not instantiated**, and `pad_miso` is placed in high-impedance (`1'bz`), preventing any bus contention with external SPI devices.

---

## 3. Module Hierarchy & Roles

| Module | Role | Technology Dependencies |
|---|---|---|
| `spi_pkg.sv` | Package constants, bit width functions, mode decoding, and performance equations | None (pure functions) |
| `spi_clock_gen.sv` | SCLK toggle generator and half-period `tick` generator | None (fully synthesizable RTL) |
| `spi_bit_counter.sv` | Bit tracking, rollover detection, and `last` pulse generator | None |
| `spi_tx_shift.sv` | Transmit shift register with glitch-free registered output; supports MSB/LSB and CPHA preloading | None |
| `spi_rx_shift.sv` | Receive shift register supporting MSB-first (left shift) and LSB-first (right shift) | None |
| `spi_cs_ctrl.sv` | Binary slave decoder to 1-hot active-low `cs_n` bus with registered outputs | None |
| `spi_master_fsm.sv` | 5-state Moore transaction sequencing engine | None |
| `spi_perf_counters.sv` | 32-bit hardware diagnostic and performance measurement counters | None |
| `spi_master.sv` | Core SPI master controller combining FSM, clock gen, shifts, and CS control | None |
| `spi_master_top.sv` | Master IP core top-level with performance counter hooks | None |
| `spi_top.sv` | Backward-compatibility alias wrapping `spi_master_top` | None |
| `spi_slave.sv` | Fully synchronous SPI slave with multi-stage input synchronizers and frame error detection | None |
| `spi_slave_top.sv` | Slave IP wrapper with tri-state MISO pad driver | Inout tri-state pad |
| `spi_pad_wrapper.sv` | SoC integration and loopback wrapper with configurable `LOOPBACK_MODE` | Inout tri-state pad |

---

## 4. Master Transaction Lifecycle

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

1. **Request Acceptance:** `start` is accepted in `S_IDLE` when `busy=0` and `slave_select < NUM_SLAVES`. `tx_data` is latched into the TX shift register.
2. **Chip-Select Setup:** `S_SELECT` asserts `cs_active`. On the next clock edge, `cs_n[slave_select]` falls LOW.
3. **Serial Transfer:** `S_TRANSFER` runs for $2 \times W \times D$ cycles. `sclk` toggles $2W$ times. MOSI and MISO are shifted and sampled on respective edges according to `SPI_MODE` and `LSB_FIRST`.
4. **Hold & Capture:** `S_DESELECT` holds CS low for $D$ cycles after SCLK returns to idle. On the last cycle, `capture` latches the deserialized word into `rx_data`.
5. **Completion Pulse:** `S_DONE` pulses `done=1` with `busy=0`. `cs_active=0` causes `cs_n` to return HIGH on the next clock edge.

---

## 5. Slave Clocking & Oversampling Constraints

The SPI slave samples external SPI pins using its local clock (`clk`):
- **Oversampling Requirement:** $f_{clk\_slave} \ge 4 \times f_{sclk}$. The half-period of SCLK must be at least 2 slave clock cycles for reliable edge detection.
- **Master-Slave Loopback Timing:** In loopback mode with an internal synchronous slave, round-trip latency through slave input synchronizers (2 cycles), edge detection (1 cycle), slave output register (1 cycle), and master MISO synchronizer (`MISO_SYNC_STAGES` cycles) requires:
  $$\text{CLOCK\_DIVIDER} \ge \text{spi\_min\_divider}(\text{MISO\_SYNC\_STAGES}) = \text{MISO\_SYNC\_STAGES} + 4 \quad (\ge 6 \text{ for 2-stage sync})$$
  Default `CLOCK_DIVIDER = 6` guarantees margin across all 4 SPI modes. For external asynchronous peripherals, `CLOCK_DIVIDER >= MISO_SYNC_STAGES + 1` applies.
