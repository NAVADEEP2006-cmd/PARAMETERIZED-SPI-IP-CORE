// -----------------------------------------------------------------------------
// spi_tx_shift.sv  -  Transmit shift register with registered output
//
// serial_out is a flop, so MOSI/MISO is glitch-free and changes only on the
// clock edge where `load` or `shift` is asserted.
//
// PRELOAD_MSB = 1 : on load the first-transmitted bit appears on serial_out
//                   immediately (CPHA=0: first bit must be valid before the
//                   first SCLK edge)
// PRELOAD_MSB = 0 : on load serial_out stays 0; the first `shift` presents
//                   the first-transmitted bit (CPHA=1: first bit is launched
//                   by the leading edge)
//
// LSB_FIRST = 0 : MSB-first. bit[DATA_WIDTH-1] transmitted first.
// LSB_FIRST = 1 : LSB-first. bit[0] transmitted first.
//
// Priority: clear > load > shift.
// -----------------------------------------------------------------------------
module spi_tx_shift #(
  parameter int DATA_WIDTH  = 8,
  parameter bit PRELOAD_MSB = 1'b1,
  parameter bit LSB_FIRST   = 1'b0
)(
  input  logic                  clk,
  input  logic                  reset,
  input  logic                  clear,
  input  logic                  load,
  input  logic                  shift,
  input  logic [DATA_WIDTH-1:0] load_data,
  output logic                  serial_out
);
  logic [DATA_WIDTH-1:0] shreg;

  // The "first bit" depends on bit order:
  //   MSB-first: load_data[DATA_WIDTH-1], shift left
  //   LSB-first: load_data[0],            shift right

  always_ff @(posedge clk) begin
    if (reset || clear) begin
      shreg      <= '0;
      serial_out <= 1'b0;                         // safe idle value
    end else if (load) begin
      if (PRELOAD_MSB) begin
        serial_out <= LSB_FIRST ? load_data[0] : load_data[DATA_WIDTH-1];
        shreg      <= LSB_FIRST ? (load_data >> 1) : (load_data << 1);
      end else begin
        serial_out <= 1'b0;
        shreg      <= load_data;
      end
    end else if (shift) begin
      serial_out <= LSB_FIRST ? shreg[0] : shreg[DATA_WIDTH-1];
      shreg      <= LSB_FIRST ? (shreg >> 1) : (shreg << 1);
    end
  end
endmodule
