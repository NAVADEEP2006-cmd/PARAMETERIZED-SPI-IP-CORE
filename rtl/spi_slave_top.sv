// -----------------------------------------------------------------------------
// spi_slave_top.sv  -  Slave IP top: spi_slave + MISO tri-state pad logic
// The only place where 'z is used. On FPGA the assign infers an OBUFT; for ASIC
// replace with the library tri-state pad cell. Keep this file out of a design
// that has an internal (non-pad) MISO bus.
// -----------------------------------------------------------------------------
module spi_slave_top #(
  parameter int DATA_WIDTH  = 8,
  parameter int SPI_MODE    = 0,
  parameter int SYNC_STAGES = 2,
  parameter bit LSB_FIRST   = 1'b0
)(
  input  logic                  clk,
  input  logic                  reset,
  input  logic                  sclk,
  input  logic                  mosi,
  input  logic                  cs_n,
  inout  wire                   miso,
  input  logic [DATA_WIDTH-1:0] tx_data,
  output logic [DATA_WIDTH-1:0] rx_data,
  output logic                  rx_valid,
  output logic                  busy,
  output logic                  frame_error
);
  logic miso_o, miso_oe;

  spi_slave #(
    .DATA_WIDTH (DATA_WIDTH),
    .SPI_MODE   (SPI_MODE),
    .SYNC_STAGES(SYNC_STAGES),
    .LSB_FIRST  (LSB_FIRST)
  ) u_slave (
    .clk, .reset, .sclk, .mosi, .cs_n, .miso_o, .miso_oe,
    .tx_data, .rx_data, .rx_valid, .busy, .frame_error
  );

  // Tri-state MISO output for pad-connected interface.
  assign miso = miso_oe ? miso_o : 1'bz;
endmodule
