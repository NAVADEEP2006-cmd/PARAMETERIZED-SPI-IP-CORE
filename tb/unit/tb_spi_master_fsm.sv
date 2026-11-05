// -----------------------------------------------------------------------------
// tb_spi_master_fsm.sv - Unit Testbench for Master Transaction FSM
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module tb_spi_master_fsm;
  localparam int CLK_PERIOD = 20;

  logic clk = 0;
  logic reset = 1;
  logic start_req = 0;
  logic tick = 0;
  logic xfer_last = 0;

  logic accept, cs_active, run, sclk_en, capture, tx_clear, busy, done;

  int errors = 0;

  always #(CLK_PERIOD/2) clk = ~clk;

  spi_master_fsm dut (
    .clk(clk),
    .reset(reset),
    .start_req(start_req),
    .tick(tick),
    .xfer_last(xfer_last),
    .accept(accept),
    .cs_active(cs_active),
    .run(run),
    .sclk_en(sclk_en),
    .capture(capture),
    .tx_clear(tx_clear),
    .busy(busy),
    .done(done)
  );

  initial begin
    #(CLK_PERIOD * 2);
    @(posedge clk);
    reset <= 0;
    @(posedge clk);

    // Initial state: S_IDLE
    if (busy !== 1'b0 || done !== 1'b0 || cs_active !== 1'b0) begin
      $display("[FAIL] Initial state outputs incorrect");
      errors++;
    end

    // Assert start_req
    start_req <= 1;
    #1;
    if (accept !== 1'b1) begin
      $display("[FAIL] accept pulse not generated on start_req");
      errors++;
    end

    @(posedge clk);
    start_req <= 0;
    // Now in S_SELECT
    if (busy !== 1'b1 || cs_active !== 1'b1 || sclk_en !== 1'b0) begin
      $display("[FAIL] S_SELECT outputs incorrect");
      errors++;
    end

    @(posedge clk);
    // Now in S_TRANSFER
    if (busy !== 1'b1 || cs_active !== 1'b1 || run !== 1'b1 || sclk_en !== 1'b1) begin
      $display("[FAIL] S_TRANSFER outputs incorrect");
      errors++;
    end

    // Signal transfer completion
    xfer_last <= 1;
    @(posedge clk);
    xfer_last <= 0;
    // Now in S_DESELECT
    if (busy !== 1'b1 || sclk_en !== 1'b0 || run !== 1'b1) begin
      $display("[FAIL] S_DESELECT outputs incorrect");
      errors++;
    end

    // Assert tick to trigger capture and transition to S_DONE
    tick <= 1;
    #1;
    if (capture !== 1'b1) begin
      $display("[FAIL] capture pulse not generated on tick in S_DESELECT");
      errors++;
    end

    @(posedge clk);
    tick <= 0;
    // Now in S_DONE
    if (done !== 1'b1 || busy !== 1'b0 || cs_active !== 1'b0 || tx_clear !== 1'b1) begin
      $display("[FAIL] S_DONE outputs incorrect: done=%b, busy=%b, cs_active=%b, tx_clear=%b",
               done, busy, cs_active, tx_clear);
      errors++;
    end

    @(posedge clk);
    // Return to S_IDLE
    if (done !== 1'b0 || busy !== 1'b0) begin
      $display("[FAIL] Return to S_IDLE failed");
      errors++;
    end

    if (errors == 0)
      $display("=== [tb_spi_master_fsm] ALL CHECKS PASSED ===");
    else
      $display("=== [tb_spi_master_fsm] FAILED with %0d errors ===", errors);

    $finish;
  end
endmodule
