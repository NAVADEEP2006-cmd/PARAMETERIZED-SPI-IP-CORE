// -----------------------------------------------------------------------------
// spi_master.sv  -  Complete SPI master (no perf counters, no pads)
//
// Timing (T = CPHA):   leading edge = SCLK leaves idle, trailing = returns
//   CPHA=0 : sample MISO on leading edge, shift MOSI on trailing edge;
//            MOSI already shows first-transmitted bit when CS falls (one
//            half-period setup).
//   CPHA=1 : shift MOSI on leading edge, sample MISO on trailing edge.
// In every mode a frame ends at the W-th trailing edge (SCLK back at CPOL);
// CS then stays low one more half-period before releasing.
// All updates happen on the same system-clock edge as the SCLK toggle; MISO is
// sampled through MISO_SYNC_STAGES flops (default 2).
//
// Parameters
//   DATA_WIDTH       bits per transaction (>=1)
//   CLOCK_DIVIDER    SCLK = clk/(2*CLOCK_DIVIDER), >= spi_min_divider(MISO_SYNC_STAGES)
//   SPI_MODE         0..3 = {CPOL,CPHA}
//   NUM_SLAVES       number of cs_n lines (>=1)
//   MISO_SYNC_STAGES input register stages on MISO (>=1)
//   LSB_FIRST        0 = MSB-first (bit[W-1] first), 1 = LSB-first (bit[0] first)
//
// System side
//   start          : request. Accepted only while busy=0 and slave_select valid.
//                    Level-sensitive: held high, transactions repeat back to back.
//   tx_data        : sampled on the accepted start cycle
//   slave_select   : binary index, sampled on the accepted start cycle
//   rx_data        : last received word, updated one cycle before `done`, held
//   busy           : high during active transaction states (S_SELECT through
//                    S_DESELECT); LOW during the done pulse cycle (S_DONE)
//   done           : 1-cycle pulse, rx_data valid in that cycle
//   error          : 1-cycle pulse when a NEW start (rising edge) is rejected
//                    because busy=1 or slave_select >= NUM_SLAVES
//   select_error   : 1-cycle pulse when a NEW start is rejected specifically
//                    because slave_select >= NUM_SLAVES (not because of busy)
//   transfer_active: SCLK is toggling
//   txn_accept     : 1-cycle pulse when a start is accepted
// Reset: synchronous, active high. SCLK=CPOL, cs_n=all 1, MOSI=0, FSM idle.
// -----------------------------------------------------------------------------
module spi_master
  import spi_pkg::*;
#(
  parameter int DATA_WIDTH       = 8,
  parameter int CLOCK_DIVIDER    = 6,
  parameter int SPI_MODE         = 0,
  parameter int NUM_SLAVES       = 1,
  parameter int MISO_SYNC_STAGES = 2,
  parameter bit LSB_FIRST        = 1'b0
)(
  input  logic                              clk,
  input  logic                              reset,
  // system side
  input  logic                              start,
  input  logic [DATA_WIDTH-1:0]             tx_data,
  input  logic [spi_idx_w(NUM_SLAVES)-1:0]  slave_select,
  output logic [DATA_WIDTH-1:0]             rx_data,
  output logic                              busy,
  output logic                              done,
  output logic                              error,
  output logic                              select_error,
  output logic                              transfer_active,
  output logic                              txn_accept,
  // SPI side
  output logic                              sclk,
  output logic                              mosi,
  input  logic                              miso,
  output logic [NUM_SLAVES-1:0]             cs_n
);
  // ---- elaboration-time parameter checks -----------------------------------
  if (DATA_WIDTH < 1)       begin : g_chk_w    $error("spi_master: DATA_WIDTH must be >= 1");       end
  if (CLOCK_DIVIDER < 1)    begin : g_chk_d    $error("spi_master: CLOCK_DIVIDER must be >= 1");    end
  if (SPI_MODE < 0 || SPI_MODE > 3) begin : g_chk_m $error("spi_master: SPI_MODE must be 0..3");     end
  if (NUM_SLAVES < 1)       begin : g_chk_s    $error("spi_master: NUM_SLAVES must be >= 1");       end
  if (MISO_SYNC_STAGES < 1) begin : g_chk_sync $error("spi_master: MISO_SYNC_STAGES must be >= 1"); end
  if (CLOCK_DIVIDER < spi_min_divider(MISO_SYNC_STAGES))
    begin : g_chk_div
      $error("spi_master: CLOCK_DIVIDER must be >= %0d for MISO_SYNC_STAGES=%0d",
             spi_min_divider(MISO_SYNC_STAGES), MISO_SYNC_STAGES);
    end

  localparam logic CPHA = spi_cpha(SPI_MODE);

  // ---- internal signals ------------------------------------------------------
  logic tick, lead_edge, trail_edge, accept;
  logic run, sclk_en, cs_active, capture, tx_clear;
  logic sel_valid, start_req, bit_last;
  logic sample_evt, shift_evt, miso_s;
  logic [DATA_WIDTH-1:0]            rx_shift_q, rx_data_r;
  logic start_q;
  logic [MISO_SYNC_STAGES-1:0] miso_sr;

  assign start_req  = start && sel_valid;
  assign sample_evt = CPHA ? trail_edge : lead_edge;
  assign shift_evt  = CPHA ? lead_edge  : trail_edge;
  assign miso_s     = miso_sr[MISO_SYNC_STAGES-1];
  assign rx_data    = rx_data_r;
  assign transfer_active = sclk_en;
  assign txn_accept = accept;

  spi_master_fsm u_fsm (
    .clk, .reset, .start_req, .tick, .xfer_last(trail_edge && bit_last),
    .accept, .cs_active, .run, .sclk_en, .capture, .tx_clear, .busy, .done
  );

  spi_clock_gen #(.CLOCK_DIVIDER(CLOCK_DIVIDER), .SPI_MODE(SPI_MODE)) u_clkgen (
    .clk, .reset, .run, .sclk_en, .tick, .lead_edge, .trail_edge, .sclk
  );

  /* verilator lint_off UNUSEDSIGNAL */
  logic [spi_idx_w(DATA_WIDTH)-1:0] bit_cnt_unused;
  /* verilator lint_on UNUSEDSIGNAL */

  // one bit period completes on every trailing edge
  spi_bit_counter #(.DATA_WIDTH(DATA_WIDTH)) u_bitcnt (
    .clk, .reset, .clear(accept), .inc(trail_edge), .count(bit_cnt_unused), .last(bit_last)
  );

  spi_tx_shift #(.DATA_WIDTH(DATA_WIDTH), .PRELOAD_MSB(CPHA == 1'b0), .LSB_FIRST(LSB_FIRST)) u_tx (
    .clk, .reset, .clear(tx_clear), .load(accept), .shift(shift_evt),
    .load_data(tx_data), .serial_out(mosi)
  );

  spi_rx_shift #(.DATA_WIDTH(DATA_WIDTH), .LSB_FIRST(LSB_FIRST)) u_rx (
    .clk, .reset, .shift(sample_evt), .serial_in(miso_s), .data(rx_shift_q)
  );

  spi_cs_ctrl #(.NUM_SLAVES(NUM_SLAVES)) u_cs (
    .clk, .reset, .load(accept), .slave_select, .cs_active, .sel_valid, .cs_n
  );

  // MISO input register chain (newest sample at bit 0)
  always_ff @(posedge clk) begin
    if (reset) miso_sr <= '0;
    else       miso_sr <= (miso_sr << 1) | MISO_SYNC_STAGES'(miso);
  end

  // RX holding register: updated in S_DESELECT, one cycle before `done`
  always_ff @(posedge clk) begin
    if (reset)        rx_data_r <= '0;
    else if (capture) rx_data_r <= rx_shift_q;
  end

  // Rejected-start flag (rising edge of start only, so a held start does not
  // flood the flag while the core is busy)
  //   error        = new start rejected for ANY reason (busy or invalid select)
  //   select_error = new start rejected specifically because slave_select invalid
  always_ff @(posedge clk) begin
    if (reset) begin
      start_q      <= 1'b0;
      error        <= 1'b0;
      select_error <= 1'b0;
    end else begin
      start_q      <= start;
      error        <= start && !start_q && (busy || !sel_valid);
      select_error <= start && !start_q && !sel_valid;
    end
  end
endmodule
