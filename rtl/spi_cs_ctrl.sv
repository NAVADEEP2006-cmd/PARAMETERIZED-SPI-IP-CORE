// -----------------------------------------------------------------------------
// spi_cs_ctrl.sv  -  Chip-select controller (active-low, registered outputs)
//
// * slave_select is latched when `load` pulses, so changing it mid-transaction
//   has no effect.
// * cs_n is decoded from the binary index, so AT MOST ONE bit is ever low:
//   simultaneous selection of two slaves is impossible by construction.
// * cs_n is registered -> glitch-free; it follows cs_active one cycle later.
// * sel_valid is a combinational check that slave_select < NUM_SLAVES.
// * Reset / idle value: all ones (all slaves deselected).
// -----------------------------------------------------------------------------
module spi_cs_ctrl
  import spi_pkg::*;
#(
  parameter int NUM_SLAVES = 1
)(
  input  logic                         clk,
  input  logic                         reset,
  input  logic                         load,
  input  logic [spi_idx_w(NUM_SLAVES)-1:0] slave_select,
  input  logic                         cs_active,
  output logic                         sel_valid,
  output logic [NUM_SLAVES-1:0]        cs_n
);
  localparam int SEL_W = spi_idx_w(NUM_SLAVES);

  logic [SEL_W-1:0]      sel_q;
  logic [NUM_SLAVES-1:0] cs_n_next;

  assign sel_valid = (int'(slave_select) < NUM_SLAVES);

  always_comb begin
    cs_n_next = '1;
    for (int i = 0; i < NUM_SLAVES; i++)
      if (cs_active && (int'(sel_q) == i)) cs_n_next[i] = 1'b0;
  end

  always_ff @(posedge clk) begin
    if (reset) begin
      sel_q <= '0;
      cs_n  <= '1;
    end else begin
      if (load) sel_q <= slave_select;
      cs_n <= cs_n_next;
    end
  end
endmodule
