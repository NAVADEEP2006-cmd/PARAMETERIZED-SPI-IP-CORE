// -----------------------------------------------------------------------------
// spi_pad_wrapper.sv  -  SPI Pad & Integration Wrapper
//
// Purpose:
//   1. Provides physical I/O pad modeling, bidirectional tri-state MISO control,
//      and pull-up termination for ASIC/FPGA integration.
//   2. Supports configurable LOOPBACK_MODE:
//      - LOOPBACK_MODE = 1: Internally routes master SPI signals to a single
//        internal slave (slave index 0) for loopback verification and self-test.
//        The master still supports NUM_SLAVES CS lines, but only slave 0 has
//        an internal loopback target. Selecting slave 1..N-1 will assert the
//        corresponding CS pad but no internal slave responds.
//        pad_miso is driven by the internal slave's tri-state output.
//      - LOOPBACK_MODE = 0: External pad mode. Master SPI signals go directly
//        to pad_sclk/pad_mosi/pad_cs_n. pad_miso is an input from external
//        devices. The internal slave is NOT instantiated and does NOT drive
//        any signal. Slave system-side ports are tied to safe defaults.
//   3. Fully compatible with Verilator lint and simulation, FPGA synthesis,
//      and ASIC standard cell pad insertion.
//
// Multi-slave note:
//   The master's cs_n[NUM_SLAVES-1:0] bus supports up to NUM_SLAVES external
//   slave devices. In loopback mode, only one internal slave is instantiated
//   (connected to cs_n[0]). This is by design: the purpose of loopback is
//   functional verification of the SPI protocol, not multi-slave arbitration.
//   For multi-CS verification, use the testbench with the master directly.
// -----------------------------------------------------------------------------
module spi_pad_wrapper
  import spi_pkg::*;
#(
  parameter int  DATA_WIDTH        = 8,
  parameter int  CLOCK_DIVIDER     = 6,
  parameter int  SPI_MODE          = 0,
  parameter int  NUM_SLAVES        = 1,
  parameter int  MISO_SYNC_STAGES  = 2,
  parameter int  SLAVE_SYNC_STAGES = 2,
  parameter bit  ENABLE_PERF       = 1'b1,
  parameter bit  LOOPBACK_MODE     = 1'b1,
  parameter bit  LSB_FIRST         = 1'b0
)(
  // Master system-side interface
  input  logic                              clk,
  input  logic                              reset,
  input  logic                              start,
  input  logic [DATA_WIDTH-1:0]             tx_data,
  input  logic [spi_idx_w(NUM_SLAVES)-1:0]  slave_select,
  output logic [DATA_WIDTH-1:0]             rx_data,
  output logic                              busy,
  output logic                              done,
  output logic                              error,
  output logic                              select_error,
  output logic                              transfer_active,

  // Performance / diagnostic counter monitoring
  input  logic                              perf_clear,
  output logic [31:0]                       perf_txn_count,
  output logic [31:0]                       perf_bits_total,
  output logic [31:0]                       perf_busy_cycles,
  output logic [31:0]                       perf_total_cycles,
  output logic [31:0]                       perf_last_latency,
  output logic [31:0]                       perf_last_sclk_cycles,
  output logic [31:0]                       perf_reject_count,

  // Slave system-side interface (active only when LOOPBACK_MODE=1)
  input  logic                              clk_slave,
  input  logic                              reset_slave,
  input  logic [DATA_WIDTH-1:0]             slave_tx_data,
  output logic [DATA_WIDTH-1:0]             slave_rx_data,
  output logic                              slave_rx_valid,
  output logic                              slave_busy,
  output logic                              slave_frame_error,

  // Physical Pad Pins (Chip / FPGA boundary)
  output logic                              pad_sclk,
  output logic                              pad_mosi,
  inout  wire                               pad_miso,
  output logic [NUM_SLAVES-1:0]             pad_cs_n
);

  // ---- Internal Core Signals ------------------------------------------------
  logic                  m_sclk;
  logic                  m_mosi;
  logic                  m_miso;
  logic [NUM_SLAVES-1:0] m_cs_n;

  // ---- Master IP Core Instantiation -----------------------------------------
  spi_master_top #(
    .DATA_WIDTH(DATA_WIDTH),
    .CLOCK_DIVIDER(CLOCK_DIVIDER),
    .SPI_MODE(SPI_MODE),
    .NUM_SLAVES(NUM_SLAVES),
    .MISO_SYNC_STAGES(MISO_SYNC_STAGES),
    .ENABLE_PERF(ENABLE_PERF),
    .LSB_FIRST(LSB_FIRST)
  ) u_spi_master_top (
    .clk                  (clk),
    .reset                (reset),
    .start                (start),
    .tx_data              (tx_data),
    .slave_select         (slave_select),
    .rx_data              (rx_data),
    .busy                 (busy),
    .done                 (done),
    .error                (error),
    .select_error         (select_error),
    .transfer_active      (transfer_active),
    .sclk                 (m_sclk),
    .mosi                 (m_mosi),
    .miso                 (m_miso),
    .cs_n                 (m_cs_n),
    .perf_clear           (perf_clear),
    .perf_txn_count       (perf_txn_count),
    .perf_bits_total      (perf_bits_total),
    .perf_busy_cycles     (perf_busy_cycles),
    .perf_total_cycles    (perf_total_cycles),
    .perf_last_latency    (perf_last_latency),
    .perf_last_sclk_cycles(perf_last_sclk_cycles),
    .perf_reject_count    (perf_reject_count)
  );

  // ---- Pad output connections (always active) --------------------------------
  assign pad_sclk = m_sclk;
  assign pad_mosi = m_mosi;
  assign pad_cs_n = m_cs_n;

  // ---- Mode-dependent interconnect ------------------------------------------
  generate
    if (LOOPBACK_MODE) begin : gen_loopback
      // ------------------------------------------------------------------
      // LOOPBACK MODE: internal slave connected to master via slave 0's CS
      // ------------------------------------------------------------------
      logic s_miso_o, s_miso_oe;

      spi_slave #(
        .DATA_WIDTH (DATA_WIDTH),
        .SPI_MODE   (SPI_MODE),
        .SYNC_STAGES(SLAVE_SYNC_STAGES),
        .LSB_FIRST  (LSB_FIRST)
      ) u_spi_slave (
        .clk        (clk_slave),
        .reset      (reset_slave),
        .sclk       (m_sclk),
        .mosi       (m_mosi),
        .cs_n       (m_cs_n[0]),          // loopback slave is always slave 0
        .miso_o     (s_miso_o),
        .miso_oe    (s_miso_oe),
        .tx_data    (slave_tx_data),
        .rx_data    (slave_rx_data),
        .rx_valid   (slave_rx_valid),
        .busy       (slave_busy),
        .frame_error(slave_frame_error)
      );

      // Master MISO: from internal slave (pull-up when slave not driving)
      assign m_miso = s_miso_oe ? s_miso_o : 1'b1;

      // pad_miso tri-state: internal slave drives pad in loopback mode
      /* verilator lint_off TRISTATE */
      assign pad_miso = s_miso_oe ? s_miso_o : 1'bz;
      /* verilator lint_on TRISTATE */

    end else begin : gen_external
      // ------------------------------------------------------------------
      // EXTERNAL MODE: master connects to external pads; no internal slave
      // ------------------------------------------------------------------

      // Master MISO comes from external pad
      assign m_miso = pad_miso;

      // pad_miso is NOT driven internally — it is owned by external device
      // No tri-state driver here; pad_miso is purely an input
      /* verilator lint_off TRISTATE */
      assign pad_miso = 1'bz;   // high-Z: external device drives this
      /* verilator lint_on TRISTATE */

      // Slave system-side ports tied to safe defaults
      assign slave_rx_data    = '0;
      assign slave_rx_valid   = 1'b0;
      assign slave_busy       = 1'b0;
      assign slave_frame_error = 1'b0;
    end
  endgenerate

endmodule
