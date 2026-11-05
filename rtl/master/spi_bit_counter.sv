// -----------------------------------------------------------------------------
// spi_bit_counter.sv
// Purpose : counts completed bit periods of one frame. Wraps to 0 after the
//           last bit so it is automatically ready for the next frame.
// Parameters : DATA_WIDTH  number of bits per frame (>=1)
// Ports   : clk, reset (sync, active high)
//           clear  synchronous clear (priority over inc)
//           inc    count one bit
//           count  bits counted so far in this frame (0 .. DATA_WIDTH-1)
//           last   high while count == DATA_WIDTH-1 (the next inc completes frame)
// -----------------------------------------------------------------------------
module spi_bit_counter
  import spi_pkg::*;
#(
  parameter int DATA_WIDTH = 8
)(
  input  logic                          clk,
  input  logic                          reset,
  input  logic                          clear,
  input  logic                          inc,
  output logic [spi_idx_w(DATA_WIDTH)-1:0] count,
  output logic                          last
);
  localparam int CNT_W = spi_idx_w(DATA_WIDTH);
  localparam logic [CNT_W-1:0] LAST_VAL = CNT_W'(DATA_WIDTH - 1);

  assign last = (count == LAST_VAL);

  always_ff @(posedge clk) begin
    if (reset || clear) count <= '0;
    else if (inc)       count <= last ? '0 : count + 1'b1;
  end
endmodule
