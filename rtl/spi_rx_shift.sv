// -----------------------------------------------------------------------------
// spi_rx_shift.sv  -  Receive shift register
//
// MSB-first (LSB_FIRST=0):
//   Each `shift` pushes serial_in into the LSB; after DATA_WIDTH shifts the
//   first received bit sits at the MSB.
// LSB-first (LSB_FIRST=1):
//   Each `shift` pushes serial_in into the MSB; after DATA_WIDTH shifts the
//   first received bit sits at the LSB.
//
// `data` is valid only after a full frame; the owning module latches it into
// its own holding register.
// -----------------------------------------------------------------------------
module spi_rx_shift #(
  parameter int DATA_WIDTH = 8,
  parameter bit LSB_FIRST  = 1'b0
)(
  input  logic                  clk,
  input  logic                  reset,
  input  logic                  shift,
  input  logic                  serial_in,
  output logic [DATA_WIDTH-1:0] data
);
  generate
    if (DATA_WIDTH == 1) begin : g_single_bit
      always_ff @(posedge clk) begin
        if (reset)      data <= '0;
        else if (shift) data <= serial_in;
      end
    end else begin : g_multi_bit
      always_ff @(posedge clk) begin
        if (reset)      data <= '0;
        else if (shift) begin
          if (LSB_FIRST)
            data <= {serial_in, data[DATA_WIDTH-1:1]};    // shift right, new bit at MSB
          else
            data <= (data << 1) | DATA_WIDTH'(serial_in); // shift left, new bit at LSB
        end
      end
    end
  endgenerate
endmodule
