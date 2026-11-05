// -----------------------------------------------------------------------------
// spi_slave.sv  -  Complete SPI slave, fully synchronous to a local clock
//
// Architecture: SCLK, CS_N and MOSI are treated as asynchronous inputs, passed
// through SYNC_STAGES-FF synchronizers and edge-detected in the local `clk`
// domain. No derived clocks, no multi-clock timing problems, same code for
// FPGA and ASIC.
//
// Oversampling constraint: local clk must oversample SCLK. Hard minimum:
//   f_clk >= 4 * f_sclk   (SCLK half period >= 2 local clock cycles)
// For a full-duplex loopback with spi_master (MISO returns ~3 clocks after
// the SCLK edge), use CLOCK_DIVIDER >= spi_min_divider(MISO_SYNC_STAGES)
// (typically >= 5 for 2-stage sync). Edge detection adds ~SYNC_STAGES+1
// clocks of latency to each SPI event.
//
// Timing (identical to the master's definitions)
//   CPHA=0: sample MOSI on leading edge, shift MISO on trailing edge; first
//           MISO bit is loaded when CS assertion is detected.
//   CPHA=1: shift MISO on leading edge, sample MOSI on trailing edge.
//
// Bit order
//   LSB_FIRST=0: MSB-first. bit[DATA_WIDTH-1] transmitted/received first.
//   LSB_FIRST=1: LSB-first. bit[0] transmitted/received first.
//
// Frame handling
//   CS falling  : tx_data is latched into the TX shift register, counters clear
//   W samples   : rx_data <= word, rx_valid pulses 1 cycle (rx_data stable
//                 until the next completed frame)
//   CS rising   : frame_error pulses if the frame was aborted (0<bits<W) or
//                 more than W clocks arrived (overrun)
//   Extra clocks after W bits are ignored for data.
// MISO: miso_o is the data, miso_oe is high only while selected. Tri-state
//       buffer lives OUTSIDE this module (see spi_slave_top).
// Reset: synchronous active high; sync chains reset to idle (SCLK=CPOL, CS=1).
// -----------------------------------------------------------------------------
module spi_slave
  import spi_pkg::*;
#(
  parameter int DATA_WIDTH  = 8,
  parameter int SPI_MODE    = 0,
  parameter int SYNC_STAGES = 2,
  parameter bit LSB_FIRST   = 1'b0
)(
  input  logic                  clk,
  input  logic                  reset,
  // SPI side
  input  logic                  sclk,
  input  logic                  mosi,
  input  logic                  cs_n,
  output logic                  miso_o,
  output logic                  miso_oe,
  // system side
  input  logic [DATA_WIDTH-1:0] tx_data,
  output logic [DATA_WIDTH-1:0] rx_data,
  output logic                  rx_valid,
  output logic                  busy,
  output logic                  frame_error
);
  if (DATA_WIDTH < 1)               begin : g_chk_w    $error("spi_slave: DATA_WIDTH must be >= 1");  end
  if (SPI_MODE < 0 || SPI_MODE > 3) begin : g_chk_m    $error("spi_slave: SPI_MODE must be 0..3");   end
  if (SYNC_STAGES < 2)              begin : g_chk_sync $error("spi_slave: SYNC_STAGES must be >= 2"); end

  localparam logic CPOL = spi_cpol(SPI_MODE);
  localparam logic CPHA = spi_cpha(SPI_MODE);

  // ---- input synchronizers + edge detection ---------------------------------
  logic [SYNC_STAGES-1:0] sclk_sync, cs_sync, mosi_sync;
  logic                   sclk_prev, cs_prev;

  always_ff @(posedge clk) begin
    if (reset) begin
      sclk_sync <= {SYNC_STAGES{CPOL}};
      sclk_prev <= CPOL;
      cs_sync   <= {SYNC_STAGES{1'b1}};
      cs_prev   <= 1'b1;
      mosi_sync <= '0;
    end else begin
      sclk_sync <= {sclk_sync[SYNC_STAGES-2:0], sclk};
      sclk_prev <= sclk_sync[SYNC_STAGES-1];
      cs_sync   <= {cs_sync[SYNC_STAGES-2:0], cs_n};
      cs_prev   <= cs_sync[SYNC_STAGES-1];
      mosi_sync <= {mosi_sync[SYNC_STAGES-2:0], mosi};
    end
  end

  logic sclk_s, cs_s, mosi_s;
  assign sclk_s = sclk_sync[SYNC_STAGES-1];
  assign cs_s   = cs_sync[SYNC_STAGES-1];
  assign mosi_s = mosi_sync[SYNC_STAGES-1];

  logic cs_fall, cs_rise;
  assign cs_fall = !cs_s &&  cs_prev;
  assign cs_rise =  cs_s && !cs_prev;

  // SCLK edges are only valid while CS is low
  logic sclk_rise, sclk_fall, lead_edge, trail_edge;
  assign sclk_rise   =  sclk_s && !sclk_prev && !cs_s;
  assign sclk_fall   = !sclk_s &&  sclk_prev && !cs_s;
  assign lead_edge   = CPOL ? sclk_fall : sclk_rise;
  assign trail_edge  = CPOL ? sclk_rise : sclk_fall;

  logic sample_evt, shift_evt;
  assign sample_evt  = CPHA ? trail_edge : lead_edge;
  assign shift_evt   = CPHA ? lead_edge  : trail_edge;

  // ---- bit counters ---------------------------------------------------------
  localparam int W_CNT = spi_idx_w(DATA_WIDTH + 1);
  logic [W_CNT-1:0] sample_cnt;
  logic full_frame_seen;

  // ---- shift registers ------------------------------------------------------
  logic [DATA_WIDTH-1:0] tx_shreg, rx_shreg;
  logic                  miso_r;

  assign miso_o  = miso_r;
  assign miso_oe = !cs_s;
  assign busy    = !cs_s;

  // TX path
  always_ff @(posedge clk) begin
    if (reset) begin
      tx_shreg <= '0;
      miso_r   <= 1'b0;
    end else if (cs_fall) begin
      if (CPHA == 1'b0) begin
        miso_r   <= LSB_FIRST ? tx_data[0] : tx_data[DATA_WIDTH-1];
        tx_shreg <= LSB_FIRST ? (tx_data >> 1) : (tx_data << 1);
      end else begin
        miso_r   <= 1'b0;
        tx_shreg <= tx_data;
      end
    end else if (shift_evt && !cs_s) begin
      miso_r   <= LSB_FIRST ? tx_shreg[0] : tx_shreg[DATA_WIDTH-1];
      tx_shreg <= LSB_FIRST ? (tx_shreg >> 1) : (tx_shreg << 1);
    end else if (cs_s) begin
      miso_r   <= 1'b0;
    end
  end

  // LSB-first shift helper: handles DATA_WIDTH=1 safely
  logic [DATA_WIDTH-1:0] rx_lsb_next;
  generate
    if (DATA_WIDTH == 1) begin : g_lsb_1b
      assign rx_lsb_next = mosi_s;
    end else begin : g_lsb_mb
      assign rx_lsb_next = {mosi_s, rx_shreg[DATA_WIDTH-1:1]};
    end
  endgenerate

  // RX path + bit count
  always_ff @(posedge clk) begin
    if (reset || cs_fall) begin
      rx_shreg        <= '0;
      sample_cnt      <= '0;
      full_frame_seen <= 1'b0;
      rx_valid        <= 1'b0;
      frame_error     <= 1'b0;
    end else begin
      rx_valid    <= 1'b0;
      frame_error <= 1'b0;

      if (sample_evt && !cs_s) begin
        if (sample_cnt < W_CNT'(DATA_WIDTH)) begin
          if (LSB_FIRST)
            rx_shreg <= rx_lsb_next;
          else
            rx_shreg <= (rx_shreg << 1) | DATA_WIDTH'(mosi_s);
          sample_cnt <= sample_cnt + 1'b1;
          if (sample_cnt == W_CNT'(DATA_WIDTH - 1)) begin
            if (LSB_FIRST)
              rx_data <= rx_lsb_next;
            else
              rx_data <= (rx_shreg << 1) | DATA_WIDTH'(mosi_s);
            rx_valid        <= 1'b1;
            full_frame_seen <= 1'b1;
          end
        end else begin
          // Overrun bit: more than DATA_WIDTH edges arrived
          sample_cnt <= sample_cnt + 1'b1;
        end
      end

      if (cs_rise) begin
        // Error if aborted early or if extra clocks occurred
        if (!full_frame_seen || (sample_cnt != W_CNT'(DATA_WIDTH))) begin
          frame_error <= 1'b1;
        end
      end
    end
  end
endmodule
