// -----------------------------------------------------------------------------
// tb_spi_clock_gen.sv - Unit Testbench for SCLK Generator
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module tb_spi_clock_gen;
  import spi_pkg::*;

  localparam int CLK_PERIOD = 20; // 50 MHz
  localparam int CLK_DIV    = 6;

  logic clk = 0;
  logic reset = 1;
  logic run = 0;
  logic sclk_en = 0;
  logic tick, lead_edge, trail_edge, sclk;

  int errors = 0;

  always #(CLK_PERIOD/2) clk = ~clk;

  spi_clock_gen #(
    .CLOCK_DIVIDER(CLK_DIV),
    .SPI_MODE(0)
  ) dut (
    .clk(clk),
    .reset(reset),
    .run(run),
    .sclk_en(sclk_en),
    .tick(tick),
    .lead_edge(lead_edge),
    .trail_edge(trail_edge),
    .sclk(sclk)
  );

  initial begin
    #(CLK_PERIOD * 2);
    @(posedge clk);
    reset <= 0;
    @(posedge clk);

    // Verify quiescent state
    if (sclk !== 1'b0) begin
      $display("[FAIL] SCLK not CPOL=0 at reset");
      errors++;
    end

    // Enable clock generator run without sclk_en
    run <= 1;
    repeat (CLK_DIV) @(posedge clk);
    if (!tick) begin
      $display("[FAIL] Tick did not fire after CLK_DIV cycles");
      errors++;
    end
    if (sclk !== 1'b0) begin
      $display("[FAIL] SCLK toggled when sclk_en=0");
      errors++;
    end

    // Enable toggling
    sclk_en <= 1;
    repeat (CLK_DIV) @(posedge clk);
    if (lead_edge !== 1'b1 || sclk !== 1'b1) begin
      $display("[FAIL] Lead edge or SCLK transition failed");
      errors++;
    end

    repeat (CLK_DIV) @(posedge clk);
    if (trail_edge !== 1'b1 || sclk !== 1'b0) begin
      $display("[FAIL] Trail edge or SCLK transition failed");
      errors++;
    end

    run <= 0;
    sclk_en <= 0;
    @(posedge clk);
    if (sclk !== 1'b0) begin
      $display("[FAIL] SCLK did not return to idle");
      errors++;
    end

    if (errors == 0) begin
      $display("=== [tb_spi_clock_gen] ALL CHECKS PASSED ===");
    end else begin
      $display("=== [tb_spi_clock_gen] FAILED with %0d errors ===", errors);
      $fatal(1, "Unit test tb_spi_clock_gen failed");
    end

    $finish;
  end
endmodule
