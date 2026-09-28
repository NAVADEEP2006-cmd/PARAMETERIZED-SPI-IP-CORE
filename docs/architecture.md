# Architecture

## Block diagram
```
host --start,tx_data,slave_select--> spi_master ----sclk,mosi,cs_n[]----> slave(s)
     <--rx_data,busy,done,error----- |  spi_master_fsm  (control)          <--miso--
                                     |  spi_clock_gen   (tick, SCLK)
                                     |  spi_tx_shift / spi_rx_shift
                                     |  spi_bit_counter
                                     |  spi_cs_ctrl
     spi_top = spi_master + spi_perf_counters (QoS hooks)
     spi_slave_top = spi_slave + MISO tri-state (only place with 'z)
```

## Design decisions
- **Reset:** synchronous, active-high `reset`. Reasons: no async-release problems, maps cleanly to FPGA fabric flops, one strategy for master and slave. Feed it from a reset synchronizer at system level.
- **Single clock domain per core.** The master uses only `clk`. The slave also runs only on its local `clk` and oversamples SCLK/CS_N/MOSI through 2-FF synchronizers (no derived clocks).
- **Mode = {CPOL, CPHA}** and really controls idle level, sample edge, shift edge and MOSI/MISO launch (see Timing).
- **MSB-first only.** Bit order is isolated in `spi_tx_shift`/`spi_rx_shift`; a future LSB-first parameter only touches those two files.
- **`done` is a 1-cycle pulse** (no acknowledge logic needed); `rx_data` is a holding register that stays valid afterwards.
- **`start` is level-sensitive** and ignored while busy; a rising-edge start that is rejected raises `error`.

## Timing definitions
SCLK period = 2·CLOCK_DIVIDER system clocks. Leading edge = SCLK leaves idle, trailing = returns to idle.

| Mode | CPOL | CPHA | Idle | Master/slave sample | Master/slave shift |
|---|---|---|---|---|---|
| 0 | 0 | 0 | low  | leading (rise)  | trailing (fall) |
| 1 | 0 | 1 | low  | trailing (fall) | leading (rise)  |
| 2 | 1 | 0 | high | leading (fall)  | trailing (rise) |
| 3 | 1 | 1 | high | trailing (rise) | leading (fall)  |

CPHA=0: bit[W-1] is already on MOSI/MISO before the first SCLK edge (loaded with CS). CPHA=1: the first leading edge launches bit[W-1].

## Module reference
| Module | Purpose | Reset behaviour |
|---|---|---|
| `spi_pkg` | width helpers, mode decode, closed-form performance functions | n/a |
| `spi_clock_gen` | half-period `tick`, `lead_edge`/`trail_edge` strobes, SCLK register. `run=0` forces SCLK=CPOL and clears the counter | SCLK=CPOL, cnt=0 |
| `spi_master_fsm` | IDLE→SELECT→TRANSFER→DESELECT→DONE→IDLE | S_IDLE |
| `spi_tx_shift` | registered MSB-first serializer, `PRELOAD_MSB` chooses CPHA behaviour | out=0 |
| `spi_rx_shift` | MSB-first deserializer | 0 |
| `spi_bit_counter` | bits completed in frame, wraps after last bit, `last` flag | 0 |
| `spi_cs_ctrl` | latches select, decodes to at-most-one-low `cs_n`, registered | all ones |
| `spi_master` | integration of the above + MISO input register + rx holding reg + error flag | idle |
| `spi_slave` | synchronizers, edge detect, shift/sample, frame status | idle, miso_oe=0 |
| `spi_perf_counters` | optional counters (ENABLE) | 0 |
| `spi_top` | master + perf, the IP's user-facing top | idle |
| `spi_slave_top` | slave + tri-state MISO pad | idle |

## Master FSM
| State | Outputs | Exit |
|---|---|---|
| S_IDLE | all inactive | `start && sel_valid` → load TX, bit counter, select → S_SELECT |
| S_SELECT | cs_active | always → S_TRANSFER |
| S_TRANSFER | cs_active, run, sclk_en | last trailing edge → S_DESELECT |
| S_DESELECT | cs_active, run | half-period `tick` → S_DONE (rx captured) |
| S_DONE | done=1, CS releases, MOSI cleared | → S_IDLE |

Reset during a transaction: FSM → S_IDLE, SCLK → CPOL, cs_n → all high immediately (frame is abandoned; slaves see a short frame).

## How a transaction works
1. **Start:** in S_IDLE with `start=1` and valid `slave_select`, `accept` pulses.
2. **TX data:** on that same clock edge `tx_data` loads the TX shift register (MSB visible on MOSI for CPHA=0), the select value and bit counter are latched/cleared.
3. **CS:** S_SELECT asserts `cs_active`; the registered `cs_n[sel]` goes low one cycle later.
4. **SCLK:** in S_TRANSFER the clock gen runs; the first SCLK edge comes one half-period after CS fell, then toggles every CLOCK_DIVIDER clocks, 2·W times.
5. **MOSI:** shifts on the shift edge of the selected mode.
6. **MISO:** goes through MISO_SYNC_STAGES flops and is sampled on the sample edge into the RX shift register.
7. **Counting:** the bit counter increments on each trailing edge; the W-th trailing edge ends the transfer.
8. **RX assembly:** first sampled bit ends up in the MSB after W shifts; it is copied into `rx_data` in S_DESELECT.
9. **Completion:** S_DONE pulses `done`, releases CS, returns MOSI to 0, then S_IDLE.

## Slave operation
CS fall → load `tx_data`, clear counters. Each sample event shifts MOSI into RX; after W samples `rx_data`/`rx_valid` update. CS rise → `frame_error` pulse if aborted or overrun. Clocks beyond W are ignored.
Limits: local clk ≥ 4× SCLK for reception; for master↔slave loopback with default MISO_SYNC_STAGES use CLOCK_DIVIDER ≥ 6 (smoke-checked in all 4 modes; ≤4 failed in mode 1). MISO stays driven ~3 clocks after CS rises (sync latency) — keep this in mind on shared MISO buses.
