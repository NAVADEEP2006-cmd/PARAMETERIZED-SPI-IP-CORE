// -----------------------------------------------------------------------------
// spi_tx_shift.sv  -  MSB-first transmit shift register with registered output
//
// serial_out is a flop, so MOSI/MISO is glitch-free and changes only on the
// clock edge where `load` or `shift` is asserted.
//
// PRELOAD_MSB = 1 : on load the MSB appears on serial_out immediately
//                   (CPHA=0: first bit must be valid before the first SCLK edge)
// PRELOAD_MSB = 0 : on load serial_out stays 0; the first `shift` presents the
//                   MSB (CPHA=1: first bit is launched by the leading edge)
//
// Priority: clear > load > shift.   Bit order is MSB first; a future LSB-first
// option only needs changes in this module and spi_rx_shift.
// -----------------------------------------------------------------------------
module spi_tx_shift #(
  parameter int DATA_WIDTH  = 8,
  parameter bit PRELOAD_MSB = 1'b1
)(
  input  logic                  clk,
  input  logic                  reset,
  input  logic                  clear,
  input  logic                  load,
  input  logic                  shift,
  input  logic [DATA_WIDTH-1:0] load_data,
  output logic                  serial_out
);
  logic [DATA_WIDTH-1:0] shreg;   // bits not yet transmitted, next bit at MSB

  always_ff @(posedge clk) begin
    if (reset || clear) begin
      shreg      <= '0;
      serial_out <= 1'b0;                         // safe idle value
    end else if (load) begin
      if (PRELOAD_MSB) begin
        serial_out <= load_data[DATA_WIDTH-1];
        shreg      <= load_data << 1;
      end else begin
        serial_out <= 1'b0;
        shreg      <= load_data;
      end
    end else if (shift) begin
      serial_out <= shreg[DATA_WIDTH-1];
      shreg      <= shreg << 1;
    end
  end
endmodule
