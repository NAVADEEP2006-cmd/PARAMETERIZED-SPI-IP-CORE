// -----------------------------------------------------------------------------
// spi_pkg.sv  -  Shared helpers for the Parameterized SPI IP Core
//
// Purpose : constant functions used for width calculation, SPI-mode decoding
//           and closed-form performance figures.
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
  // Minimum legal CLOCK_DIVIDER for reliable MISO sampling.
  // The synchronizer adds MISO_SYNC_STAGES cycles of latency; the slave (in
  // loopback) adds ~3 cycles after the SCLK edge before MISO is valid.
  // To ensure the sample edge sees stable data:
  //   CLOCK_DIVIDER >= MISO_SYNC_STAGES + 3   (for loopback with internal slave)
  //   CLOCK_DIVIDER >= MISO_SYNC_STAGES + 1   (for external slave, conservative)
  // We enforce the tighter (loopback) constraint here.
  // ---------------------------------------------------------------------------
  function automatic int spi_min_divider(input int miso_sync_stages);
    return miso_sync_stages + 3;
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
  //   D + 2  (1 cycle S_SELECT + D cycles S_DESELECT + 1 cycle S_DONE)
  function automatic int unsigned spi_overhead_cycles(input int D);
    return D + 2;
  endfunction

  // Total transaction latency from accepted start through done pulse (inclusive):
  //   2*W*D + D + 2
  function automatic int unsigned spi_latency_cycles(input int W, input int D);
    return spi_sclk_cycles(W, D) + spi_overhead_cycles(D);
  endfunction

  // Active busy cycles of one transaction (cycles where busy == 1):
  //   S_SELECT (1) + S_TRANSFER (2*W*D) + S_DESELECT (D) = 2*W*D + D + 1
  //   (Note: busy is 0 during the S_DONE completion pulse)
  function automatic int unsigned spi_busy_cycles(input int W, input int D);
    return spi_sclk_cycles(W, D) + D + 1;
  endfunction

  // Payload throughput in bit/s for back-to-back transactions
  // (start held high: 1 idle/turnaround cycle between transactions).
  function automatic longint unsigned spi_payload_bps(input longint unsigned clk_hz,
                                                      input int W, input int D);
    return (clk_hz * 64'(W)) / (64'(spi_latency_cycles(W, D)) + 64'd1);
  endfunction

endpackage
