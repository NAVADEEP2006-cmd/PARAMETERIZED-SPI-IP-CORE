// -----------------------------------------------------------------------------
// spi_clock_gen.sv  -  SCLK generator / half-period timing base
//
// Definitions
//   SCLK period      = 2*CLOCK_DIVIDER system-clock cycles
//   f_sclk           = f_clk / (2*CLOCK_DIVIDER)      (CLOCK_DIVIDER >= 1)
//   CLOCK_DIVIDER=1  -> SCLK toggles every clock (f_clk/2, the maximum)
//   Idle level       = CPOL (from SPI_MODE)
//   `tick`           = one-cycle strobe every CLOCK_DIVIDER cycles while `run`
//
// Behaviour
//   run=0            : counter cleared, SCLK forced to CPOL
//   run=1, sclk_en=0 : counter runs, `tick` is produced, SCLK stays idle
//                      (used for the CS setup / hold half-periods)
//   run=1, sclk_en=1 : every tick toggles SCLK
//   lead_edge  = tick that moves SCLK away from idle (same clock edge on which
//                sclk register changes)
//   trail_edge = tick that returns SCLK to idle
//   The first tick after `run` rises occurs CLOCK_DIVIDER-1 cycles later, so the
//   first SCLK edge is exactly one half-period after `run` rose.
// Reset: synchronous; SCLK = CPOL, counter = 0.
// -----------------------------------------------------------------------------
module spi_clock_gen
  import spi_pkg::*;
#(
  parameter int CLOCK_DIVIDER = 6,
  parameter int SPI_MODE      = 0
)(
  input  logic clk,
  input  logic reset,
  input  logic run,
  input  logic sclk_en,
  output logic tick,
  output logic lead_edge,
  output logic trail_edge,
  output logic sclk
);
  localparam logic CPOL = spi_cpol(SPI_MODE);
  localparam int   CNT_W = spi_idx_w(CLOCK_DIVIDER);          // >=1 even for divider 1
  localparam logic [CNT_W-1:0] CNT_LAST = CNT_W'(CLOCK_DIVIDER - 1);

  logic [CNT_W-1:0] cnt;
  logic             sclk_r;

  assign tick       = run && (cnt == CNT_LAST);
  assign lead_edge  = tick && sclk_en && (sclk_r == CPOL);
  assign trail_edge = tick && sclk_en && (sclk_r != CPOL);
  assign sclk       = sclk_r;

  always_ff @(posedge clk) begin
    if (reset || !run)        cnt <= '0;
    else if (cnt == CNT_LAST) cnt <= '0;             // rollover (also divider = 1)
    else                      cnt <= cnt + 1'b1;
  end

  always_ff @(posedge clk) begin
    if (reset || !run)        sclk_r <= CPOL;
    else if (tick && sclk_en) sclk_r <= ~sclk_r;
  end
endmodule
