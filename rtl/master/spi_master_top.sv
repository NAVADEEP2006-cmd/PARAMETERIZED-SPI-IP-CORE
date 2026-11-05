// -----------------------------------------------------------------------------
// spi_master_top.sv  -  Parameterized SPI IP: top level (master + perf counters)
//
//   host logic --start/tx_data/slave_select--> [ spi_master ] --sclk/mosi/cs_n--> slave(s)
//              <--rx_data/busy/done/error----- [            ] <--miso------------
//                                              [ perf counters ] --> perf_*
// Instantiate spi_slave / spi_slave_top separately for the slave role.
// Technology independent: no primitives, no tri-states.
// -----------------------------------------------------------------------------
module spi_master_top
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
  input  logic                              reset,        // sync, active high
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
  // SPI side
  output logic                              sclk,
  output logic                              mosi,
  input  logic                              miso,
  output logic [NUM_SLAVES-1:0]             cs_n,
  // performance / diagnostic counter hooks
  input  logic                              perf_clear,
  output logic [31:0]                       perf_txn_count,
  output logic [31:0]                       perf_bits_total,
  output logic [31:0]                       perf_busy_cycles,
  output logic [31:0]                       perf_total_cycles,
  output logic [31:0]                       perf_last_latency,
  output logic [31:0]                       perf_last_sclk_cycles,
  output logic [31:0]                       perf_reject_count
);
  /* verilator lint_off UNUSEDSIGNAL */
  logic txn_accept_unused;
  /* verilator lint_on UNUSEDSIGNAL */

  spi_master #(
    .DATA_WIDTH(DATA_WIDTH), .CLOCK_DIVIDER(CLOCK_DIVIDER), .SPI_MODE(SPI_MODE),
    .NUM_SLAVES(NUM_SLAVES), .MISO_SYNC_STAGES(MISO_SYNC_STAGES), .LSB_FIRST(LSB_FIRST)
  ) u_master (
    .clk, .reset, .start, .tx_data, .slave_select, .rx_data,
    .busy, .done, .error, .select_error, .transfer_active, .txn_accept(txn_accept_unused),
    .sclk, .mosi, .miso, .cs_n
  );

  spi_perf_counters #(.ENABLE(ENABLE_PERF), .DATA_WIDTH(DATA_WIDTH)) u_perf (
    .clk, .reset, .clear(perf_clear), .busy, .done, .transfer_active,
    .start_error(error),
    .txn_count(perf_txn_count), .bits_total(perf_bits_total),
    .busy_cycles(perf_busy_cycles), .total_cycles(perf_total_cycles),
    .last_latency(perf_last_latency), .last_sclk_cycles(perf_last_sclk_cycles),
    .reject_count(perf_reject_count)
  );
endmodule
