// -----------------------------------------------------------------------------
// tb_spi_shift_regs.sv - Unit Testbench for TX and RX Shift Registers
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module tb_spi_shift_regs;
  localparam int CLK_PERIOD = 20;
  localparam int DATA_WIDTH = 8;

  logic clk = 0;
  logic reset = 1;
  logic tx_clear = 0;
  logic tx_load = 0;
  logic tx_shift = 0;
  logic [DATA_WIDTH-1:0] tx_data = 8'hA5;
  logic mosi;

  logic rx_shift = 0;
  logic [DATA_WIDTH-1:0] rx_data;

  int errors = 0;

  always #(CLK_PERIOD/2) clk = ~clk;

  // MSB-first TX (CPHA=0 -> PRELOAD_MSB=1)
  spi_tx_shift #(
    .DATA_WIDTH(DATA_WIDTH),
    .PRELOAD_MSB(1'b1),
    .LSB_FIRST(1'b0)
  ) u_tx (
    .clk(clk),
    .reset(reset),
    .clear(tx_clear),
    .load(tx_load),
    .shift(tx_shift),
    .load_data(tx_data),
    .serial_out(mosi)
  );

  // MSB-first RX
  spi_rx_shift #(
    .DATA_WIDTH(DATA_WIDTH),
    .LSB_FIRST(1'b0)
  ) u_rx (
    .clk(clk),
    .reset(reset),
    .shift(rx_shift),
    .serial_in(mosi),
    .data(rx_data)
  );

  initial begin
    #(CLK_PERIOD * 2);
    @(posedge clk);
    reset <= 0;
    @(posedge clk);

    // Load 8'hA5 (10100101) into TX
    tx_load <= 1;
    @(posedge clk);
    tx_load <= 0;

    // First bit (MSB = 1) is immediately preloaded on MOSI
    if (mosi !== 1'b1) begin
      $display("[FAIL] TX preloaded MSB expected 1, got %b", mosi);
      errors++;
    end

    // Shift through RX
    for (int i = 0; i < DATA_WIDTH; i++) begin
      rx_shift <= 1;
      @(posedge clk);
      rx_shift <= 0;
      if (i < DATA_WIDTH - 1) begin
        tx_shift <= 1;
        @(posedge clk);
        tx_shift <= 0;
      end
    end

    @(posedge clk);
    if (rx_data !== 8'hA5) begin
      $display("[FAIL] RX received data mismatch: expected 0xA5, got 0x%02X", rx_data);
      errors++;
    end

    if (errors == 0)
      $display("=== [tb_spi_shift_regs] ALL CHECKS PASSED ===");
    else
      $display("=== [tb_spi_shift_regs] FAILED with %0d errors ===", errors);

    $finish;
  end
endmodule
