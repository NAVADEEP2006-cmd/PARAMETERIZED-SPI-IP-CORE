# Parameters and performance definitions

There is no register file (no AXI/APB wrapper); the IP is configured by parameters and controlled through the system-side ports.

## Parameters
| Parameter | Default | Range | Meaning |
|---|---|---|---|
| DATA_WIDTH | 8 | ≥1 (8/16/32 intended) | bits per transaction; sizes shift regs and bit counter |
| CLOCK_DIVIDER (D) | 4 | ≥1 | SCLK period = 2·D clocks; f_sclk = f_clk/(2D) |
| SPI_MODE | 0 | 0–3 | {CPOL,CPHA} |
| NUM_SLAVES | 1 | ≥1 (1/2/4 intended) | cs_n width; select port width |
| MISO_SYNC_STAGES | 1 | ≥1 | MISO input flops; needs D > stages + slave delay |
| ENABLE_PERF | 1 | 0/1 | include perf counters |
| slave: DATA_WIDTH, SPI_MODE | | | must match the master |

Invalid values raise an elaboration `$error` (tools without support for elaboration tasks in generate blocks ignore them; check parameters manually).

## Derived performance (W = DATA_WIDTH, D = CLOCK_DIVIDER)
| Quantity | Formula |
|---|---|
| SCLK frequency | f_clk / (2D) |
| SCLK-active cycles | 2·W·D |
| Fixed overhead (CS setup/hold, FSM) | D + 2 cycles |
| Transaction latency (accepted start → `done`) = busy cycles | 2·W·D + D + 2 cycles |
| Back-to-back period (start held high) | latency + 1 idle cycle |
| Payload throughput (back-to-back) | f_clk · W / (2·W·D + D + 3) bit/s |
| Efficiency vs raw SCLK rate | W·2D / (2WD + D + 3) |

Example: W=8, D=6, f_clk=100 MHz → f_sclk = 8.33 MHz, latency 2·8·6+6+2 = 104 cycles (1.04 µs), back-to-back payload = 100e6·8/(96+6+3) ≈ 7.62 Mbit/s.
These formulas were cross-checked against the perf counters in a quick throwaway simulation; proper verification is still to be done.

## Measured counters (`perf_*`)
| Output | Meaning |
|---|---|
| txn_count / bits_total | completed transactions / bits transferred |
| busy_cycles / total_cycles | utilization = busy / total |
| last_latency | busy cycles of last transaction (= latency formula) |
| last_sclk_cycles | SCLK-active cycles of last transaction (2WD) |
| CS/FSM overhead | last_latency − last_sclk_cycles |
| reject_count | rejected starts |
Counters wrap at 2^32; `perf_clear` clears them.
