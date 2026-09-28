// -----------------------------------------------------------------------------
// spi_pkg.sv  -  Shared helpers for the Parameterized SPI IP Core
//
// Purpose : constant functions used for width calculation, SPI-mode decoding
//           and closed-form performance (QoS) figures.
// Note    : every function is a pure constant function (no state), so the
//           package is fully synthesizable / elaboration-time only.
//           Compile this file FIRST.
// -----------------------------------------------------------------------------
package spi_pkg;

  // Safe clog2 helper avoiding zero-width vectors when n <= 1
  function automatic int clog2_safe(input int n);
    return (n > 1) ? $clog2(n) : 1;
  endfunction

  // spi_idx_w alias for backwards compatibility
  function automatic int spi_idx_w(input int n);
    return clog2_safe(n);
  endfunction

  // SPI mode decode:  mode = {CPOL, CPHA}
  //   0 -> CPOL=0 CPHA=0   1 -> CPOL=0 CPHA=1
  //   2 -> CPOL=1 CPHA=0   3 -> CPOL=1 CPHA=1
  function automatic logic spi_cpol(input int mode);
    return (mode == 2) || (mode == 3);
  endfunction

  function automatic logic spi_cpha(input int mode);
    return (mode == 1) || (mode == 3);
  endfunction

  // ---------------------------------------------------------------------------
  // Closed-form performance figures (derived, not measured).
  //   W = DATA_WIDTH, D = CLOCK_DIVIDER, clk_hz = system clock in Hz.
  //   SCLK period = 2*D system-clock cycles.
  // ---------------------------------------------------------------------------
  // SCLK frequency in Hz
  function automatic longint unsigned spi_sclk_hz(input longint unsigned clk_hz,
                                                  input int D);
    return clk_hz / (2 * D);
  endfunction

  // Cycles in which SCLK is toggling (TRANSFER state): 2*W*D
  function automatic int unsigned spi_sclk_cycles(input int W, input int D);
    return 2 * W * D;
  endfunction

  // Fixed per-transaction overhead in system-clock cycles:
  //   D + 2  (CS setup/hold half-periods and FSM state cycles;
  //           see docs/register_parameter_spec.md)
  function automatic int unsigned spi_overhead_cycles(input int D);
    return D + 2;
  endfunction

  // Busy time of one transaction = latency from accepted start to done pulse
  function automatic int unsigned spi_busy_cycles(input int W, input int D);
    return spi_sclk_cycles(W, D) + spi_overhead_cycles(D);
  endfunction

  // Payload throughput in bit/s for back-to-back transactions
  // (start held high: one extra IDLE cycle between transactions).
  function automatic longint unsigned spi_payload_bps(input longint unsigned clk_hz,
                                                      input int W, input int D);
    return (clk_hz * 64'(W)) / (64'(spi_busy_cycles(W, D)) + 64'd1);
  endfunction

endpackage
