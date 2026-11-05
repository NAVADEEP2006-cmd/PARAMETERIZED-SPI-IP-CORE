// -----------------------------------------------------------------------------
// tb_spi_bit_counter.sv - Unit Testbench for SPI Bit Counter
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module tb_spi_bit_counter;
  import spi_pkg::*;

  localparam int CLK_PERIOD = 20;
  localparam int DATA_WIDTH = 8;

  logic clk = 0;
  logic reset = 1;
  logic clear = 0;
  logic inc = 0;
  logic [spi_idx_w(DATA_WIDTH)-1:0] count;
  logic last;

  int errors = 0;

  always #(CLK_PERIOD/2) clk = ~clk;

  spi_bit_counter #(
    .DATA_WIDTH(DATA_WIDTH)
  ) dut (
    .clk(clk),
    .reset(reset),
    .clear(clear),
    .inc(inc),
    .count(count),
    .last(last)
  );

  initial begin
    #(CLK_PERIOD * 2);
    @(posedge clk);
    reset <= 0;
    @(posedge clk);

    if (count !== 0 || last !== 0) begin
      $display("[FAIL] Initial reset failed");
      errors++;
    end

    // Count 7 bits
    for (int i = 0; i < 7; i++) begin
      inc <= 1;
      @(posedge clk);
      inc <= 0;
      @(posedge clk);
      if (count !== (i + 1)) begin
        $display("[FAIL] Expected count %0d, got %0d", i + 1, count);
        errors++;
      end
    end

    // At count 7 (DATA_WIDTH-1), last should be asserted
    if (last !== 1'b1) begin
      $display("[FAIL] Last bit flag not asserted at count 7");
      errors++;
    end

    // Rollover on 8th inc
    inc <= 1;
    @(posedge clk);
    inc <= 0;
    @(posedge clk);
    if (count !== 0 || last !== 0) begin
      $display("[FAIL] Rollover failed: count=%0d, last=%0d", count, last);
      errors++;
    end

    // Test synchronous clear priority
    inc <= 1;
    clear <= 1;
    @(posedge clk);
    clear <= 0;
    inc <= 0;
    @(posedge clk);
    if (count !== 0) begin
      $display("[FAIL] Clear priority failed: count=%0d", count);
      errors++;
    end

    if (errors == 0) begin
      $display("=== [tb_spi_bit_counter] ALL CHECKS PASSED ===");
    end else begin
      $display("=== [tb_spi_bit_counter] FAILED with %0d errors ===", errors);
      $fatal(1, "Unit test tb_spi_bit_counter failed");
    end

    $finish;
  end
endmodule
