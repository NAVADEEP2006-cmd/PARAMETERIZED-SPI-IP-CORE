# Interface specification (`spi_top`)

## System side
| Signal | Dir | Width | Definition |
|---|---|---|---|
| clk | in | 1 | system clock |
| reset | in | 1 | synchronous, active high |
| start | in | 1 | request. Accepted when `busy=0` and `slave_select < NUM_SLAVES`. Level-sensitive: held high repeats transactions back to back. Ignored while busy |
| tx_data | in | DATA_WIDTH | sampled on the accepted-start cycle |
| slave_select | in | ceil(log2(NUM_SLAVES)), min 1 | binary slave index, sampled on accepted start. For NUM_SLAVES=1 tie to 0 |
| rx_data | out | DATA_WIDTH | last received word; valid from the `done` cycle until the next `done` |
| busy | out | 1 | high from the cycle after accepted start through the `done` cycle |
| done | out | 1 | one-clock pulse, `rx_data` valid |
| error | out | 1 | one-clock pulse when a rising-edge `start` is rejected (busy or invalid select) |
| transfer_active | out | 1 | SCLK is toggling |

Usage: set `tx_data`/`slave_select`, pulse `start` one clock, wait for `done`, read `rx_data`. Start while busy is ignored; reset during a transaction aborts it.

## SPI side
| Signal | Dir | Definition |
|---|---|---|
| sclk | out | idle level = CPOL |
| mosi | out | 0 when idle |
| miso | in | sampled through MISO_SYNC_STAGES flops |
| cs_n[NUM_SLAVES-1:0] | out | active low, all high when idle, at most one low |

## Perf hooks
`perf_clear` (in) and `perf_*` (out, 32-bit): see `register_parameter_spec.md`.

## Slave (`spi_slave` / `spi_slave_top`)
| Signal | Dir | Definition |
|---|---|---|
| sclk, mosi, cs_n | in | SPI inputs (asynchronous, synchronized internally) |
| miso_o / miso_oe | out | data / drive enable (internal core). `spi_slave_top` exposes `inout miso` |
| tx_data | in | latched on CS assertion |
| rx_data, rx_valid | out | received word, 1-cycle valid pulse |
| busy | out | CS asserted |
| frame_error | out | 1-cycle pulse at CS release for an aborted frame or more than W clocks |

I/O constraints (pin locations, IO standards, clock constraint) belong in the FPGA project, not in the RTL.
