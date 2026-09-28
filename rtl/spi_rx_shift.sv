// -----------------------------------------------------------------------------
// spi_rx_shift.sv  -  MSB-first receive shift register
// Each `shift` pulse pushes serial_in into the LSB; after DATA_WIDTH shifts the
// first received bit sits at the MSB. `data` is valid only after a full frame;
// the owning module latches it into its own holding register.
// -----------------------------------------------------------------------------
module spi_rx_shift #(
  parameter int DATA_WIDTH = 8
)(
  input  logic                  clk,
  input  logic                  reset,
  input  logic                  shift,
  input  logic                  serial_in,
  output logic [DATA_WIDTH-1:0] data
);
  always_ff @(posedge clk) begin
    if (reset)      data <= '0;
    else if (shift) data <= (data << 1) | DATA_WIDTH'(serial_in);
  end
endmodule
