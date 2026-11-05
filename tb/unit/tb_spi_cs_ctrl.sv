// -----------------------------------------------------------------------------
// tb_spi_cs_ctrl.sv - Unit Testbench for Chip Select Controller
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module tb_spi_cs_ctrl;
  import spi_pkg::*;

  localparam int CLK_PERIOD = 20;
  localparam int NUM_SLAVES = 4;

  logic clk = 0;
  logic reset = 1;
  logic load = 0;
  logic [spi_idx_w(NUM_SLAVES)-1:0] slave_select = 0;
  logic cs_active = 0;
  logic sel_valid;
  logic [NUM_SLAVES-1:0] cs_n;

  int errors = 0;

  always #(CLK_PERIOD/2) clk = ~clk;

  spi_cs_ctrl #(
    .NUM_SLAVES(NUM_SLAVES)
  ) dut (
    .clk(clk),
    .reset(reset),
    .load(load),
    .slave_select(slave_select),
    .cs_active(cs_active),
    .sel_valid(sel_valid),
    .cs_n(cs_n)
  );

  initial begin
    #(CLK_PERIOD * 2);
    @(posedge clk);
    reset <= 0;
    @(posedge clk);

    // Initial check: all cs_n must be high (deselected)
    if (cs_n !== 4'b1111) begin
      $display("[FAIL] cs_n reset level is not 4'b1111");
      errors++;
    end

    // Test select validity
    slave_select <= 2;
    #1;
    if (sel_valid !== 1'b1) begin
      $display("[FAIL] Valid slave_select rejected");
      errors++;
    end

    slave_select <= 4;
    #1;
    if (sel_valid !== 1'b0) begin
      $display("[FAIL] Out of range slave_select accepted as valid");
      errors++;
    end

    // Select slave 2
    slave_select <= 2;
    load <= 1;
    @(posedge clk);
    load <= 0;
    cs_active <= 1;
    @(posedge clk);
    // cs_n follows cs_active one cycle later
    if (cs_n !== 4'b1011) begin
      $display("[FAIL] Expected cs_n = 4'b1011, got %b", cs_n);
      errors++;
    end

    // Deactivate cs
    cs_active <= 0;
    @(posedge clk);
    if (cs_n !== 4'b1111) begin
      $display("[FAIL] cs_n did not return to 4'b1111 upon deactivation");
      errors++;
    end

    if (errors == 0) begin
      $display("=== [tb_spi_cs_ctrl] ALL CHECKS PASSED ===");
    end else begin
      $display("=== [tb_spi_cs_ctrl] FAILED with %0d errors ===", errors);
      $fatal(1, "Unit test tb_spi_cs_ctrl failed");
    end

    $finish;
  end
endmodule
