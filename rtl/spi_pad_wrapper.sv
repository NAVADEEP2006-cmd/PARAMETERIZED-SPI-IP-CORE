// -----------------------------------------------------------------------------
// spi_pad_wrapper.sv  -  SPI Pad & Integration Wrapper
//
// Purpose:
//   1. Provides physical I/O pad modeling, bidirectional tri-state MISO control,
//      and pull-up termination for ASIC/FPGA integration.
//   2. Supports configurable LOOPBACK_MODE (default 1'b1):
//      - When LOOPBACK_MODE = 1: Internally integrates master and slave cores
//        for loopback verification and self-test while driving pad pins.
//      - When LOOPBACK_MODE = 0: Connects directly to external board/chip pads.
//   3. Fully compatible with Verilator lint and simulation, FPGA synthesis,
//      and ASIC standard cell pad insertion.
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
  parameter bit  LOOPBACK_MODE     = 1'b1
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

  // Performance / QoS monitoring
  input  logic                              perf_clear,
  output logic [31:0]                       perf_txn_count,
  output logic [31:0]                       perf_bits_total,
  output logic [31:0]                       perf_busy_cycles,
  output logic [31:0]                       perf_total_cycles,
  output logic [31:0]                       perf_last_latency,
  output logic [31:0]                       perf_last_sclk_cycles,
  output logic [31:0]                       perf_reject_count,

  // Slave system-side interface
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

  logic                  s_sclk;
  logic                  s_mosi;
  logic                  s_cs_n;
  logic                  s_miso_o;
  logic                  s_miso_oe;

  // ---- Master IP Core Instantiation -----------------------------------------
  spi_master_top #(
    .DATA_WIDTH(DATA_WIDTH),
    .CLOCK_DIVIDER(CLOCK_DIVIDER),
    .SPI_MODE(SPI_MODE),
    .NUM_SLAVES(NUM_SLAVES),
    .MISO_SYNC_STAGES(MISO_SYNC_STAGES),
    .ENABLE_PERF(ENABLE_PERF)
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

  // ---- Slave IP Core Instantiation ------------------------------------------
  spi_slave #(
    .DATA_WIDTH (DATA_WIDTH),
    .SPI_MODE   (SPI_MODE),
    .SYNC_STAGES(SLAVE_SYNC_STAGES)
  ) u_spi_slave (
    .clk        (clk_slave),
    .reset      (reset_slave),
    .sclk       (s_sclk),
    .mosi       (s_mosi),
    .cs_n       (s_cs_n),
    .miso_o     (s_miso_o),
    .miso_oe    (s_miso_oe),
    .tx_data    (slave_tx_data),
    .rx_data    (slave_rx_data),
    .rx_valid   (slave_rx_valid),
    .busy       (slave_busy),
    .frame_error(slave_frame_error)
  );

  // ---- Interconnect & Pad Logic ---------------------------------------------
  // Pad outputs driven by Master
  assign pad_sclk = m_sclk;
  assign pad_mosi = m_mosi;
  assign pad_cs_n = m_cs_n;

  // Slave inputs selection
  generate
    if (LOOPBACK_MODE) begin : gen_loopback
      // Direct internal routing for verification loopback
      assign s_sclk = m_sclk;
      assign s_mosi = m_mosi;
      assign s_cs_n = m_cs_n[0];

      // Resolved MISO with pull-up model: when slave is not driving, line is pulled high (1'b1)
      assign m_miso = s_miso_oe ? s_miso_o : 1'b1;
    end else begin : gen_external
      // External pad connection mode
      assign s_sclk = pad_sclk;
      assign s_mosi = pad_mosi;
      assign s_cs_n = pad_cs_n[0];
      assign m_miso = pad_miso;
    end
  endgenerate

  // Bidirectional Pad Tri-State Driver (with lint guards for Verilator)
  /* verilator lint_off TRISTATE */
  assign pad_miso = s_miso_oe ? s_miso_o : 1'bz;
  /* verilator lint_on TRISTATE */

endmodule
