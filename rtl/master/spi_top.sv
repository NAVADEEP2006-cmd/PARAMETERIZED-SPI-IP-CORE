// -----------------------------------------------------------------------------
// spi_top.sv  -  Alias wrapper to spi_master_top for backward compatibility
//
// Exposes the same interface as spi_master_top, including select_error.
// This module is a transparent pass-through; it generates no additional logic.
// -----------------------------------------------------------------------------
module spi_top
  import spi_pkg::*;
#(
  parameter int DATA_WIDTH       = 8,
  parameter int CLOCK_DIVIDER    = 6,
  parameter int SPI_MODE         = 0,
  parameter int NUM_SLAVES       = 1,
  parameter int MISO_SYNC_STAGES = 2,
  parameter bit ENABLE_PERF      = 1'b1,
  parameter bit LSB_FIRST        = 1'b0
)(
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
  output logic                              sclk,
  output logic                              mosi,
  input  logic                              miso,
  output logic [NUM_SLAVES-1:0]             cs_n,
  input  logic                              perf_clear,
  output logic [31:0]                       perf_txn_count,
  output logic [31:0]                       perf_bits_total,
  output logic [31:0]                       perf_busy_cycles,
  output logic [31:0]                       perf_total_cycles,
  output logic [31:0]                       perf_last_latency,
  output logic [31:0]                       perf_last_sclk_cycles,
  output logic [31:0]                       perf_reject_count
);
  spi_master_top #(
    .DATA_WIDTH(DATA_WIDTH),
    .CLOCK_DIVIDER(CLOCK_DIVIDER),
    .SPI_MODE(SPI_MODE),
    .NUM_SLAVES(NUM_SLAVES),
    .MISO_SYNC_STAGES(MISO_SYNC_STAGES),
    .ENABLE_PERF(ENABLE_PERF),
    .LSB_FIRST(LSB_FIRST)
  ) u_impl (
    .clk, .reset, .start, .tx_data, .slave_select, .rx_data,
    .busy, .done, .error, .select_error, .transfer_active,
    .sclk, .mosi, .miso, .cs_n,
    .perf_clear, .perf_txn_count, .perf_bits_total, .perf_busy_cycles,
    .perf_total_cycles, .perf_last_latency, .perf_last_sclk_cycles, .perf_reject_count
  );
endmodule
