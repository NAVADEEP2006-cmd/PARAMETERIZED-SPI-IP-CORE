// -----------------------------------------------------------------------------
// tb_spi_pynq_z2_top.sv - Dedicated Self-Checking Board-Top Testbench
//
// Verification Scope:
//   1. Reset startup and release behaviour
//   2. Start-button synchronization and debouncing (rejection of transient glitches)
//   3. Exactly one transaction per button press (holding start button high)
//   4. Slave selection from switches (SW[1:0] decoding to pad_cs_n[3:0])
//   5. Transaction payload progression (tx_data incrementing across transactions)
//   6. LED status behaviour (busy, transfer-active, pulse-stretched done, error)
//   7. SPI outputs and chip-select timing and signals
//
// Target Module: rtl/board/spi_pynq_z2_top.sv
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module tb_spi_pynq_z2_top;
  import spi_pkg::*;

  /* verilator lint_off UNUSEDSIGNAL */

  // ---- Testbench Configuration Parameters -----------------------------------
  localparam int CLK_PERIOD          = 8;   // 125 MHz (8.000 ns period)
  localparam int DATA_WIDTH          = 8;
  localparam int CLOCK_DIVIDER       = 15;  // 125 MHz / 30 = 4.167 MHz SCLK
  localparam int SPI_MODE            = 0;
  localparam int NUM_SLAVES          = 4;
  localparam bit LSB_FIRST           = 1'b0;
  localparam int DEBOUNCE_LIMIT      = 20;  // Scaled for simulation tractability
  localparam int DONE_STRETCH_CYCLES = 50;  // Scaled for simulation tractability
  localparam int ERR_STRETCH_CYCLES  = 100;

  // DUT Signal Connections
  logic                  sysclk;
  logic                  reset_btn;
  logic                  start_btn;
  logic [1:0]            sw_slave_sel;
  wire                   pad_sclk;
  wire                   pad_mosi;
  logic                  pad_miso;
  wire  [NUM_SLAVES-1:0] pad_cs_n;
  wire                   led_busy;
  wire                   led_done;
  wire                   led_error;
  wire                   led_active;

  // Global Test Statistics
  int total_tests = 0;
  int pass_count  = 0;
  int fail_count  = 0;

  // Clock Generation (125 MHz)
  initial sysclk = 0;
  always #(CLK_PERIOD/2) sysclk <= ~sysclk;

  // ---------------------------------------------------------------------------
  // DUT Instantiation
  // ---------------------------------------------------------------------------
  spi_pynq_z2_top #(
    .DATA_WIDTH          (DATA_WIDTH),
    .CLOCK_DIVIDER       (CLOCK_DIVIDER),
    .SPI_MODE            (SPI_MODE),
    .NUM_SLAVES          (NUM_SLAVES),
    .LSB_FIRST           (LSB_FIRST),
    .DEBOUNCE_LIMIT      (DEBOUNCE_LIMIT),
    .DONE_STRETCH_CYCLES (DONE_STRETCH_CYCLES),
    .ERR_STRETCH_CYCLES  (ERR_STRETCH_CYCLES)
  ) dut (
    .sysclk              (sysclk),
    .reset_btn           (reset_btn),
    .start_btn           (start_btn),
    .sw_slave_sel        (sw_slave_sel),
    .pad_sclk            (pad_sclk),
    .pad_mosi            (pad_mosi),
    .pad_miso            (pad_miso),
    .pad_cs_n            (pad_cs_n),
    .led_busy            (led_busy),
    .led_done            (led_done),
    .led_error           (led_error),
    .led_active          (led_active)
  );

  // ---------------------------------------------------------------------------
  // Helper Verification Task
  // ---------------------------------------------------------------------------
  task automatic check_result(
    input string name,
    input logic  condition,
    input string details
  );
    total_tests++;
    if (condition) begin
      pass_count++;
      $display("[PASS] %s: %s", name, details);
    end else begin
      fail_count++;
      $display("[FAIL] %s: %s", name, details);
    end
  endtask

  // Task to press and hold start button through debouncing and release
  task automatic press_and_release_button();
    // Press button and hold for > DEBOUNCE_LIMIT cycles
    start_btn = 1'b1;
    repeat (DEBOUNCE_LIMIT + 5) @(posedge sysclk);
    #1;
    // Release button and hold low for > DEBOUNCE_LIMIT cycles
    start_btn = 1'b0;
    repeat (DEBOUNCE_LIMIT + 5) @(posedge sysclk);
    #1;
  endtask

  // ---------------------------------------------------------------------------
  // Main Verification Sequence
  // ---------------------------------------------------------------------------
  logic [7:0] captured_mosi;
  int bit_idx;
  int done_pulse_count;

  initial begin
    $dumpfile("tb_spi_pynq_z2_top.vcd");
    $dumpvars(0, tb_spi_pynq_z2_top);

    $display("==================================================================");
    $display("      PYNQ-Z2 BOARD TOP (spi_pynq_z2_top) VERIFICATION SUITE      ");
    $display("==================================================================");

    // Initialize inputs
    reset_btn    = 1'b1; // Assert reset at power-up
    start_btn    = 1'b0;
    sw_slave_sel = 2'b00;
    pad_miso     = 1'b1;

    // =========================================================================
    // TEST 1: Reset Startup and Release Behaviour
    // =========================================================================
    $display("\n--- TEST 1: Reset Startup and Release Behaviour ---");
    repeat (10) @(posedge sysclk);
    #1;
    check_result("Reset Active: pad_cs_n", pad_cs_n == 4'b1111,
                 "All CS lines deasserted high during reset");
    check_result("Reset Active: pad_sclk", pad_sclk == 1'b0,
                 "SCLK idle low during reset (Mode 0)");
    check_result("Reset Active: led_busy", led_busy == 1'b0,
                 "led_busy is 0 during reset");
    check_result("Reset Active: led_done", led_done == 1'b0,
                 "led_done is 0 during reset");
    check_result("Reset Active: led_error", led_error == 1'b0,
                 "led_error is 0 during reset");
    check_result("Reset Active: led_active", led_active == 1'b0,
                 "led_active is 0 during reset");

    // Release reset
    reset_btn = 1'b0;
    repeat (5) @(posedge sysclk);
    #1;
    check_result("Reset Released: Quiescent State",
                 (pad_cs_n == 4'b1111) && (pad_sclk == 1'b0) && (led_busy == 1'b0),
                 "Outputs remain quiescent and idle after reset release");

    // =========================================================================
    // TEST 2: Start-Button Synchronization and Debouncing
    // =========================================================================
    $display("\n--- TEST 2: Start-Button Synchronization and Debouncing ---");

    // Inject mechanical contact bounce glitches shorter than DEBOUNCE_LIMIT
    for (int b = 0; b < 4; b++) begin
      start_btn = 1'b1;
      repeat (5) @(posedge sysclk); // 5 cycles < DEBOUNCE_LIMIT (20)
      #1;
      start_btn = 1'b0;
      repeat (5) @(posedge sysclk);
      #1;
    end
    check_result("Debounce Glitch Filter", led_busy == 1'b0 && pad_cs_n == 4'b1111,
                 "Contact bounces (< DEBOUNCE_LIMIT) rejected without triggering transaction");

    // Now hold button steadily for DEBOUNCE_LIMIT + 5 cycles to initiate transaction
    start_btn = 1'b1;
    repeat (DEBOUNCE_LIMIT + 5) @(posedge sysclk);
    #1;
    start_btn = 1'b0;

    // Transaction should now be active
    repeat (5) @(posedge sysclk);
    #1;
    check_result("Debounced Trigger Accepted", led_busy == 1'b1 && led_active == 1'b1,
                 "Valid debounced press initiates transaction (busy=1, active=1)");

    // Wait for transaction to complete
    while (led_busy) @(posedge sysclk);
    #1;
    check_result("Debounced Transaction Completion", led_busy == 1'b0,
                 "Transaction completes and returns to idle");

    // Allow done LED stretch to expire
    repeat (DONE_STRETCH_CYCLES + 10) @(posedge sysclk);
    #1;

    // =========================================================================
    // TEST 3: Exactly One Transaction Per Button Press (Holding Button High)
    // =========================================================================
    $display("\n--- TEST 3: Exactly One Transaction Per Button Press ---");
    // Hold start_btn high across the ENTIRE transaction and beyond
    start_btn = 1'b1;

    // Wait until transaction starts
    while (!led_busy) @(posedge sysclk);
    #1;
    check_result("Hold Test: Transaction Started", led_busy == 1'b1,
                 "Transaction begins while button held high");

    // Keep holding start_btn high until transaction finishes
    while (led_busy) @(posedge sysclk);
    #1;
    check_result("Hold Test: Transaction Done", led_busy == 1'b0,
                 "First transaction finishes while button still held high");

    // Keep holding button for another 100 cycles to verify NO second transaction starts
    repeat (100) @(posedge sysclk);
    #1;
    check_result("Hold Test: No Spurious Re-trigger", led_busy == 1'b0,
                 "Core remains idle; no secondary transaction occurs while button is held");

    // Release button
    start_btn = 1'b0;
    repeat (DEBOUNCE_LIMIT + 10) @(posedge sysclk);
    #1;

    // =========================================================================
    // TEST 4: Slave Selection from Switches (SW[1:0] to pad_cs_n[3:0])
    // =========================================================================
    $display("\n--- TEST 4: Slave Selection from Switches ---");
    for (int s = 0; s < NUM_SLAVES; s++) begin
      sw_slave_sel = 2'(s);
      repeat (5) @(posedge sysclk); // Allow synchronizers to settle
      #1;

      // Trigger transaction
      start_btn = 1'b1;
      repeat (DEBOUNCE_LIMIT + 5) @(posedge sysclk);
      #1;
      start_btn = 1'b0;

      // Wait for core to enter transfer state
      while (!led_active) @(posedge sysclk);
      #1;

      // Check active-low chip select assertion
      check_result($sformatf("Slave %0d Selected (pad_cs_n[%0d]==0)", s, s),
                   pad_cs_n[s] == 1'b0,
                   $sformatf("pad_cs_n[%0d] asserted low during transfer", s));

      // Check all unselected slaves remain deasserted (high)
      for (int other = 0; other < NUM_SLAVES; other++) begin
        if (other != s) begin
          check_result($sformatf("Slave %0d Deselected (sel=%0d)", other, s),
                       pad_cs_n[other] == 1'b1,
                       $sformatf("pad_cs_n[%0d] held high while slave %0d is active", other, s));
        end
      end

      // Wait for transfer completion
      while (led_busy) @(posedge sysclk);
      repeat (DEBOUNCE_LIMIT + 5) @(posedge sysclk);
      #1;
    end

    // =========================================================================
    // TEST 5: Transaction Payload Progression
    // =========================================================================
    $display("\n--- TEST 5: Transaction Payload Progression ---");
    // After reset, initial pattern was 0xA5.
    // 1st press (Test 2) incremented and transmitted: 0xA6
    // 2nd press (Test 3) incremented and transmitted: 0xA7
    // 3rd-6th presses (Test 4, 4 slaves) transmitted: 0xA8, 0xA9, 0xAA, 0xAB
    // Next transaction (7th press) should transmit:   0xAC (8'b1010_1100)
    sw_slave_sel = 2'b00;
    repeat (5) @(posedge sysclk);

    start_btn = 1'b1;
    repeat (DEBOUNCE_LIMIT + 5) @(posedge sysclk);
    #1;
    start_btn = 1'b0;

    // Capture MOSI data bits sampled on SCLK rising edge (Mode 0: CPOL=0, CPHA=0)
    while (!led_active) @(posedge sysclk);
    captured_mosi = 8'h00;
    for (bit_idx = DATA_WIDTH-1; bit_idx >= 0; bit_idx--) begin
      @(posedge pad_sclk);
      captured_mosi[bit_idx] = pad_mosi;
    end

    while (led_busy) @(posedge sysclk);
    #1;
    check_result("Payload Progression 0xAC", captured_mosi == 8'hAC,
                 $sformatf("Captured MOSI: 0x%02X (expected: 0xAC)", captured_mosi));

    repeat (DEBOUNCE_LIMIT + 5) @(posedge sysclk);
    #1;

    // Next transaction (8th press) should transmit: 0xAD (8'b1010_1101)
    start_btn = 1'b1;
    repeat (DEBOUNCE_LIMIT + 5) @(posedge sysclk);
    #1;
    start_btn = 1'b0;

    while (!led_active) @(posedge sysclk);
    captured_mosi = 8'h00;
    for (bit_idx = DATA_WIDTH-1; bit_idx >= 0; bit_idx--) begin
      @(posedge pad_sclk);
      captured_mosi[bit_idx] = pad_mosi;
    end

    while (led_busy) @(posedge sysclk);
    #1;
    check_result("Payload Progression 0xAD", captured_mosi == 8'hAD,
                 $sformatf("Captured MOSI: 0x%02X (expected: 0xAD)", captured_mosi));

    repeat (DEBOUNCE_LIMIT + 5) @(posedge sysclk);
    #1;

    // =========================================================================
    // TEST 6: LED Status Behaviour
    // =========================================================================
    $display("\n--- TEST 6: LED Status Behaviour ---");
    // Trigger transaction and observe LED sequence
    start_btn = 1'b1;
    repeat (DEBOUNCE_LIMIT + 5) @(posedge sysclk);
    #1;
    start_btn = 1'b0;

    while (!led_busy) @(posedge sysclk);
    #1;
    check_result("LED: led_busy asserted", led_busy == 1'b1, "led_busy is 1 during transaction");
    check_result("LED: led_active asserted", led_active == 1'b1, "led_active is 1 during transfer");
    check_result("LED: led_error quiescent", led_error == 1'b0, "led_error remains 0 for valid transaction");

    // Wait for transaction to finish
    while (led_busy) @(posedge sysclk);
    #1;
    check_result("LED: led_done pulse-stretched", led_done == 1'b1,
                 "led_done is asserted immediately after transaction completes");

    // Verify led_done remains asserted for multiple cycles (stretched)
    repeat (DONE_STRETCH_CYCLES / 2) @(posedge sysclk);
    #1;
    check_result("LED: led_done stretch persistence", led_done == 1'b1,
                 "led_done persists during stretch duration");

    // Wait for done stretch to expire
    repeat (DONE_STRETCH_CYCLES) @(posedge sysclk);
    #1;
    check_result("LED: led_done returns low", led_done == 1'b0,
                 "led_done deasserts after stretch counter completes");

    // =========================================================================
    // TEST 7: SPI Outputs and Chip-Select Selection
    // =========================================================================
    $display("\n--- TEST 7: SPI Outputs and Chip-Select Timing ---");
    sw_slave_sel = 2'b10; // Select slave 2
    repeat (5) @(posedge sysclk);

    start_btn = 1'b1;
    repeat (DEBOUNCE_LIMIT + 5) @(posedge sysclk);
    #1;
    start_btn = 1'b0;

    while (!led_active) @(posedge sysclk);
    #1;
    check_result("SPI CS Timing: pad_cs_n[2] Low", pad_cs_n[2] == 1'b0,
                 "Selected chip select low during active serial transfer");
    check_result("SPI SCLK Active", pad_sclk !== 1'bx,
                 "pad_sclk is defined and valid");

    while (led_busy) @(posedge sysclk);
    #1;
    check_result("SPI CS Post-Transaction: pad_cs_n[2] High", pad_cs_n[2] == 1'b1,
                 "Selected chip select returns high upon transaction completion");
    check_result("SPI SCLK Idle: Mode 0", pad_sclk == 1'b0,
                 "pad_sclk returns to idle low level");

    // =========================================================================
    // Final Summary Report
    // =========================================================================
    $display("\n==================================================================");
    $display("       spi_pynq_z2_top BOARD TOP VERIFICATION SUMMARY REPORT       ");
    $display("==================================================================");
    $display(" Total Tests Executed : %0d", total_tests);
    $display(" Tests Passed         : %0d", pass_count);
    $display(" Tests Failed         : %0d", fail_count);
    if (fail_count == 0) begin
      $display(" Final Status         : [PASSED] ALL BOARD TOP CHECKS PASSED!");
    end else begin
      $display(" Final Status         : [FAILED] SOME BOARD TOP CHECKS FAILED!");
    end
    $display("==================================================================\n");

    if (fail_count > 0) $fatal(1, "Board Top Testbench FAILED");
    $finish;
  end

  // Watchdog Timer
  initial begin
    repeat (1000000) @(posedge sysclk);
    $display("\n[ERROR] Watchdog timer expired in tb_spi_pynq_z2_top! Aborting.");
    $fatal(1, "Watchdog timeout");
  end

endmodule
