// -----------------------------------------------------------------------------
// spi_tb.sv  -  Comprehensive Self-Checking Testbench for Parameterized SPI IP
//
// Verification Scope:
//    1. Reset & Idle Pin Level Verification (All 4 SPI Modes)
//    2. SPI Mode 0 Full-Duplex Transfer (CPOL=0, CPHA=0)
//    3. SPI Mode 1 Full-Duplex Transfer (CPOL=0, CPHA=1)
//    4. SPI Mode 2 Full-Duplex Transfer (CPOL=1, CPHA=0)
//    5. SPI Mode 3 Full-Duplex Transfer (CPOL=1, CPHA=1)
//    6. Performance / Diagnostic Counter Verification & Synchronous Clear
//    7. Error Semantics & Semantic Separation (select_error vs error)
//    8. Back-to-Back Consecutive Streaming Transfers
//    9. 16-Bit Parameterized Word Transfer
//   10. 32-Bit Parameterized Word Transfer
//   11. LSB-First Bit Ordering Full-Duplex Transfer
//   12. Multi-Slave 1-Hot CS Assertion & Decoding (NUM_SLAVES=4)
//   13. Synchronous Reset During Active Transaction
//   14. Single-Bit Word Transfer Boundary (DATA_WIDTH=1)
//   15. Minimum Legal Clock Divider Boundary (CLOCK_DIVIDER=5, MISO_SYNC_STAGES=2)
//   16. Reset Lifecycle Verification (Reset Before Transfer & Reset After Transfer)
//
// Compatibility:
//   - Verilator (v5+ with --timing and --binary)
//   - Icarus Verilog (iverilog -g2012)
//   - Major Commercial EDA Toolchains (ModelSim, Questa, VCS, Xcelium, Vivado)
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module spi_tb;
  import spi_pkg::*;

  /* verilator lint_off UNUSEDSIGNAL */

  // ---- Testbench Configuration Parameters -----------------------------------
  localparam int CLK_PERIOD_MASTER = 20; // 50 MHz
  localparam int CLK_PERIOD_SLAVE  = 20; // 50 MHz
  localparam int TIMEOUT_CYCLES    = 100000;

  // Global Test Counters
  int total_tests = 0;
  int pass_count  = 0;
  int fail_count  = 0;

  // Master & Slave Clocks and Resets
  logic clk_m = 0;
  logic clk_s = 0;
  logic rst_m = 1;
  logic rst_s = 1;

  always #(CLK_PERIOD_MASTER/2) clk_m <= ~clk_m;
  always #(CLK_PERIOD_SLAVE/2)  clk_s <= ~clk_s;

  // ---------------------------------------------------------------------------
  // DUT 0: Mode 0 (CPOL=0, CPHA=0), 8-bit, Divider=6, MSB-first, Perf Enabled
  // ---------------------------------------------------------------------------
  logic        m0_start, m0_busy, m0_done, m0_error, m0_sel_err, m0_xfer_act, m0_perf_clr;
  logic [7:0]  m0_tx_data, m0_rx_data;
  logic [0:0]  m0_slave_sel;
  logic [31:0] m0_txn_cnt, m0_bits_tot, m0_busy_cyc, m0_tot_cyc, m0_lat, m0_sclk_cyc, m0_rej_cnt;
  logic [7:0]  s0_tx_data, s0_rx_data;
  logic        s0_rx_valid, s0_busy, s0_frame_err;
  wire         pad0_sclk, pad0_mosi, pad0_miso;
  wire  [0:0]  pad0_cs_n;

  spi_pad_wrapper #(
    .DATA_WIDTH(8), .CLOCK_DIVIDER(6), .SPI_MODE(0), .NUM_SLAVES(1),
    .LOOPBACK_MODE(1), .LSB_FIRST(0), .ENABLE_PERF(1'b1)
  ) dut_mode0 (
    .clk(clk_m), .reset(rst_m), .start(m0_start), .tx_data(m0_tx_data), .slave_select(m0_slave_sel),
    .rx_data(m0_rx_data), .busy(m0_busy), .done(m0_done), .error(m0_error), .select_error(m0_sel_err),
    .transfer_active(m0_xfer_act), .perf_clear(m0_perf_clr),
    .perf_txn_count(m0_txn_cnt), .perf_bits_total(m0_bits_tot), .perf_busy_cycles(m0_busy_cyc),
    .perf_total_cycles(m0_tot_cyc), .perf_last_latency(m0_lat), .perf_last_sclk_cycles(m0_sclk_cyc),
    .perf_reject_count(m0_rej_cnt),
    .clk_slave(clk_s), .reset_slave(rst_s), .slave_tx_data(s0_tx_data), .slave_rx_data(s0_rx_data),
    .slave_rx_valid(s0_rx_valid), .slave_busy(s0_busy), .slave_frame_error(s0_frame_err),
    .pad_sclk(pad0_sclk), .pad_mosi(pad0_mosi), .pad_miso(pad0_miso), .pad_cs_n(pad0_cs_n)
  );

  // ---------------------------------------------------------------------------
  // DUT 1: Mode 1 (CPOL=0, CPHA=1), 8-bit, Divider=6, MSB-first
  // ---------------------------------------------------------------------------
  logic        m1_start, m1_busy, m1_done, m1_error, m1_sel_err;
  logic [7:0]  m1_tx_data, m1_rx_data;
  logic [0:0]  m1_slave_sel;
  logic [7:0]  s1_tx_data, s1_rx_data;
  logic        s1_rx_valid, s1_busy, s1_frame_err;
  wire         pad1_sclk, pad1_mosi, pad1_miso;
  wire  [0:0]  pad1_cs_n;

  spi_pad_wrapper #(
    .DATA_WIDTH(8), .CLOCK_DIVIDER(6), .SPI_MODE(1), .NUM_SLAVES(1),
    .LOOPBACK_MODE(1), .LSB_FIRST(0), .ENABLE_PERF(1'b0)
  ) dut_mode1 (
    .clk(clk_m), .reset(rst_m), .start(m1_start), .tx_data(m1_tx_data), .slave_select(m1_slave_sel),
    .rx_data(m1_rx_data), .busy(m1_busy), .done(m1_done), .error(m1_error), .select_error(m1_sel_err),
    .transfer_active(), .perf_clear(1'b0),
    .perf_txn_count(), .perf_bits_total(), .perf_busy_cycles(),
    .perf_total_cycles(), .perf_last_latency(), .perf_last_sclk_cycles(),
    .perf_reject_count(),
    .clk_slave(clk_s), .reset_slave(rst_s), .slave_tx_data(s1_tx_data), .slave_rx_data(s1_rx_data),
    .slave_rx_valid(s1_rx_valid), .slave_busy(s1_busy), .slave_frame_error(s1_frame_err),
    .pad_sclk(pad1_sclk), .pad_mosi(pad1_mosi), .pad_miso(pad1_miso), .pad_cs_n(pad1_cs_n)
  );

  // ---------------------------------------------------------------------------
  // DUT 2: Mode 2 (CPOL=1, CPHA=0), 8-bit, Divider=6, MSB-first
  // ---------------------------------------------------------------------------
  logic        m2_start, m2_busy, m2_done, m2_error, m2_sel_err;
  logic [7:0]  m2_tx_data, m2_rx_data;
  logic [0:0]  m2_slave_sel;
  logic [7:0]  s2_tx_data, s2_rx_data;
  logic        s2_rx_valid, s2_busy, s2_frame_err;
  wire         pad2_sclk, pad2_mosi, pad2_miso;
  wire  [0:0]  pad2_cs_n;

  spi_pad_wrapper #(
    .DATA_WIDTH(8), .CLOCK_DIVIDER(6), .SPI_MODE(2), .NUM_SLAVES(1),
    .LOOPBACK_MODE(1), .LSB_FIRST(0), .ENABLE_PERF(1'b0)
  ) dut_mode2 (
    .clk(clk_m), .reset(rst_m), .start(m2_start), .tx_data(m2_tx_data), .slave_select(m2_slave_sel),
    .rx_data(m2_rx_data), .busy(m2_busy), .done(m2_done), .error(m2_error), .select_error(m2_sel_err),
    .transfer_active(), .perf_clear(1'b0),
    .perf_txn_count(), .perf_bits_total(), .perf_busy_cycles(),
    .perf_total_cycles(), .perf_last_latency(), .perf_last_sclk_cycles(),
    .perf_reject_count(),
    .clk_slave(clk_s), .reset_slave(rst_s), .slave_tx_data(s2_tx_data), .slave_rx_data(s2_rx_data),
    .slave_rx_valid(s2_rx_valid), .slave_busy(s2_busy), .slave_frame_error(s2_frame_err),
    .pad_sclk(pad2_sclk), .pad_mosi(pad2_mosi), .pad_miso(pad2_miso), .pad_cs_n(pad2_cs_n)
  );

  // ---------------------------------------------------------------------------
  // DUT 3: Mode 3 (CPOL=1, CPHA=1), 8-bit, Divider=6, MSB-first
  // ---------------------------------------------------------------------------
  logic        m3_start, m3_busy, m3_done, m3_error, m3_sel_err;
  logic [7:0]  m3_tx_data, m3_rx_data;
  logic [0:0]  m3_slave_sel;
  logic [7:0]  s3_tx_data, s3_rx_data;
  logic        s3_rx_valid, s3_busy, s3_frame_err;
  wire         pad3_sclk, pad3_mosi, pad3_miso;
  wire  [0:0]  pad3_cs_n;

  spi_pad_wrapper #(
    .DATA_WIDTH(8), .CLOCK_DIVIDER(6), .SPI_MODE(3), .NUM_SLAVES(1),
    .LOOPBACK_MODE(1), .LSB_FIRST(0), .ENABLE_PERF(1'b0)
  ) dut_mode3 (
    .clk(clk_m), .reset(rst_m), .start(m3_start), .tx_data(m3_tx_data), .slave_select(m3_slave_sel),
    .rx_data(m3_rx_data), .busy(m3_busy), .done(m3_done), .error(m3_error), .select_error(m3_sel_err),
    .transfer_active(), .perf_clear(1'b0),
    .perf_txn_count(), .perf_bits_total(), .perf_busy_cycles(),
    .perf_total_cycles(), .perf_last_latency(), .perf_last_sclk_cycles(),
    .perf_reject_count(),
    .clk_slave(clk_s), .reset_slave(rst_s), .slave_tx_data(s3_tx_data), .slave_rx_data(s3_rx_data),
    .slave_rx_valid(s3_rx_valid), .slave_busy(s3_busy), .slave_frame_error(s3_frame_err),
    .pad_sclk(pad3_sclk), .pad_mosi(pad3_mosi), .pad_miso(pad3_miso), .pad_cs_n(pad3_cs_n)
  );

  // ---------------------------------------------------------------------------
  // DUT 4: 16-Bit Word Transfer (Mode 0, Divider=6, MSB-first)
  // ---------------------------------------------------------------------------
  logic        m16_start, m16_busy, m16_done, m16_error, m16_sel_err;
  logic [15:0] m16_tx_data, m16_rx_data;
  logic [0:0]  m16_slave_sel;
  logic [15:0] s16_tx_data, s16_rx_data;
  logic        s16_rx_valid, s16_busy, s16_frame_err;
  wire         pad16_sclk, pad16_mosi, pad16_miso;
  wire  [0:0]  pad16_cs_n;

  spi_pad_wrapper #(
    .DATA_WIDTH(16), .CLOCK_DIVIDER(6), .SPI_MODE(0), .NUM_SLAVES(1),
    .LOOPBACK_MODE(1), .LSB_FIRST(0), .ENABLE_PERF(1'b0)
  ) dut_w16 (
    .clk(clk_m), .reset(rst_m), .start(m16_start), .tx_data(m16_tx_data), .slave_select(m16_slave_sel),
    .rx_data(m16_rx_data), .busy(m16_busy), .done(m16_done), .error(m16_error), .select_error(m16_sel_err),
    .transfer_active(), .perf_clear(1'b0),
    .perf_txn_count(), .perf_bits_total(), .perf_busy_cycles(),
    .perf_total_cycles(), .perf_last_latency(), .perf_last_sclk_cycles(),
    .perf_reject_count(),
    .clk_slave(clk_s), .reset_slave(rst_s), .slave_tx_data(s16_tx_data), .slave_rx_data(s16_rx_data),
    .slave_rx_valid(s16_rx_valid), .slave_busy(s16_busy), .slave_frame_error(s16_frame_err),
    .pad_sclk(pad16_sclk), .pad_mosi(pad16_mosi), .pad_miso(pad16_miso), .pad_cs_n(pad16_cs_n)
  );

  // ---------------------------------------------------------------------------
  // DUT 5: 32-Bit Word Transfer (Mode 2, Divider=6, MSB-first)
  // ---------------------------------------------------------------------------
  logic        m32_start, m32_busy, m32_done, m32_error, m32_sel_err;
  logic [31:0] m32_tx_data, m32_rx_data;
  logic [0:0]  m32_slave_sel;
  logic [31:0] s32_tx_data, s32_rx_data;
  logic        s32_rx_valid, s32_busy, s32_frame_err;
  wire         pad32_sclk, pad32_mosi, pad32_miso;
  wire  [0:0]  pad32_cs_n;

  spi_pad_wrapper #(
    .DATA_WIDTH(32), .CLOCK_DIVIDER(6), .SPI_MODE(2), .NUM_SLAVES(1),
    .LOOPBACK_MODE(1), .LSB_FIRST(0), .ENABLE_PERF(1'b0)
  ) dut_w32 (
    .clk(clk_m), .reset(rst_m), .start(m32_start), .tx_data(m32_tx_data), .slave_select(m32_slave_sel),
    .rx_data(m32_rx_data), .busy(m32_busy), .done(m32_done), .error(m32_error), .select_error(m32_sel_err),
    .transfer_active(), .perf_clear(1'b0),
    .perf_txn_count(), .perf_bits_total(), .perf_busy_cycles(),
    .perf_total_cycles(), .perf_last_latency(), .perf_last_sclk_cycles(),
    .perf_reject_count(),
    .clk_slave(clk_s), .reset_slave(rst_s), .slave_tx_data(s32_tx_data), .slave_rx_data(s32_rx_data),
    .slave_rx_valid(s32_rx_valid), .slave_busy(s32_busy), .slave_frame_error(s32_frame_err),
    .pad_sclk(pad32_sclk), .pad_mosi(pad32_mosi), .pad_miso(pad32_miso), .pad_cs_n(pad32_cs_n)
  );

  // ---------------------------------------------------------------------------
  // DUT 6: LSB-first Mode 0, 8-bit, Divider=6
  // ---------------------------------------------------------------------------
  logic        lsb_start, lsb_busy, lsb_done, lsb_error, lsb_sel_err;
  logic [7:0]  lsb_tx_data, lsb_rx_data;
  logic [0:0]  lsb_slave_sel;
  logic [7:0]  lsb_s_tx_data, lsb_s_rx_data;
  logic        lsb_s_rx_valid, lsb_s_busy, lsb_s_frame_err;
  wire         lsb_pad_sclk, lsb_pad_mosi, lsb_pad_miso;
  wire  [0:0]  lsb_pad_cs_n;

  spi_pad_wrapper #(
    .DATA_WIDTH(8), .CLOCK_DIVIDER(6), .SPI_MODE(0), .NUM_SLAVES(1),
    .LOOPBACK_MODE(1), .LSB_FIRST(1), .ENABLE_PERF(1'b0)
  ) dut_lsb (
    .clk(clk_m), .reset(rst_m), .start(lsb_start), .tx_data(lsb_tx_data), .slave_select(lsb_slave_sel),
    .rx_data(lsb_rx_data), .busy(lsb_busy), .done(lsb_done), .error(lsb_error), .select_error(lsb_sel_err),
    .transfer_active(), .perf_clear(1'b0),
    .perf_txn_count(), .perf_bits_total(), .perf_busy_cycles(),
    .perf_total_cycles(), .perf_last_latency(), .perf_last_sclk_cycles(),
    .perf_reject_count(),
    .clk_slave(clk_s), .reset_slave(rst_s), .slave_tx_data(lsb_s_tx_data), .slave_rx_data(lsb_s_rx_data),
    .slave_rx_valid(lsb_s_rx_valid), .slave_busy(lsb_s_busy), .slave_frame_error(lsb_s_frame_err),
    .pad_sclk(lsb_pad_sclk), .pad_mosi(lsb_pad_mosi), .pad_miso(lsb_pad_miso), .pad_cs_n(lsb_pad_cs_n)
  );

  // ---------------------------------------------------------------------------
  // DUT 7: Multi-slave CS verification (NUM_SLAVES=4, Mode 0, 8-bit)
  // Uses spi_master_top directly (no pad wrapper) to verify CS decoding
  // ---------------------------------------------------------------------------
  logic        ms_start, ms_busy, ms_done, ms_error, ms_sel_err;
  logic [7:0]  ms_tx_data, ms_rx_data;
  logic [1:0]  ms_slave_sel;  // 2-bit for 4 slaves
  logic        ms_sclk, ms_mosi, ms_miso;
  logic [3:0]  ms_cs_n;

  spi_master_top #(
    .DATA_WIDTH(8), .CLOCK_DIVIDER(6), .SPI_MODE(0),
    .NUM_SLAVES(4), .MISO_SYNC_STAGES(2), .ENABLE_PERF(1'b0)
  ) dut_multi_slave (
    .clk(clk_m), .reset(rst_m), .start(ms_start), .tx_data(ms_tx_data),
    .slave_select(ms_slave_sel), .rx_data(ms_rx_data),
    .busy(ms_busy), .done(ms_done), .error(ms_error), .select_error(ms_sel_err),
    .transfer_active(),
    .sclk(ms_sclk), .mosi(ms_mosi), .miso(ms_miso), .cs_n(ms_cs_n),
    .perf_clear(1'b0),
    .perf_txn_count(), .perf_bits_total(),
    .perf_busy_cycles(), .perf_total_cycles(),
    .perf_last_latency(), .perf_last_sclk_cycles(),
    .perf_reject_count()
  );

  assign ms_miso = 1'b1;

  // ---------------------------------------------------------------------------
  // DUT 8: Single-Bit Parameterized Word Transfer (DATA_WIDTH=1, Mode 0, Divider=6)
  // ---------------------------------------------------------------------------
  logic        m1b_start, m1b_busy, m1b_done, m1b_error, m1b_sel_err;
  logic [0:0]  m1b_tx_data, m1b_rx_data;
  logic [0:0]  m1b_slave_sel;
  logic [0:0]  s1b_tx_data, s1b_rx_data;
  logic        s1b_rx_valid, s1b_busy, s1b_frame_err;
  wire         pad1b_sclk, pad1b_mosi, pad1b_miso;
  wire  [0:0]  pad1b_cs_n;

  spi_pad_wrapper #(
    .DATA_WIDTH(1), .CLOCK_DIVIDER(6), .SPI_MODE(0), .NUM_SLAVES(1),
    .LOOPBACK_MODE(1), .LSB_FIRST(0), .ENABLE_PERF(1'b0)
  ) dut_w1 (
    .clk(clk_m), .reset(rst_m), .start(m1b_start), .tx_data(m1b_tx_data), .slave_select(m1b_slave_sel),
    .rx_data(m1b_rx_data), .busy(m1b_busy), .done(m1b_done), .error(m1b_error), .select_error(m1b_sel_err),
    .transfer_active(), .perf_clear(1'b0),
    .perf_txn_count(), .perf_bits_total(), .perf_busy_cycles(),
    .perf_total_cycles(), .perf_last_latency(), .perf_last_sclk_cycles(),
    .perf_reject_count(),
    .clk_slave(clk_s), .reset_slave(rst_s), .slave_tx_data(s1b_tx_data), .slave_rx_data(s1b_rx_data),
    .slave_rx_valid(s1b_rx_valid), .slave_busy(s1b_busy), .slave_frame_error(s1b_frame_err),
    .pad_sclk(pad1b_sclk), .pad_mosi(pad1b_mosi), .pad_miso(pad1b_miso), .pad_cs_n(pad1b_cs_n)
  );

  // ---------------------------------------------------------------------------
  // DUT 9: Minimum Legal Clock Divider Boundary (CLOCK_DIVIDER=5, MISO_SYNC_STAGES=1)
  // ---------------------------------------------------------------------------
  logic        mmin_start, mmin_busy, mmin_done, mmin_error, mmin_sel_err;
  logic [7:0]  mmin_tx_data, mmin_rx_data;
  logic [0:0]  mmin_slave_sel;
  logic [7:0]  smin_tx_data, smin_rx_data;
  logic        smin_rx_valid, smin_busy, smin_frame_err;
  wire         padmin_sclk, padmin_mosi, padmin_miso;
  wire  [0:0]  padmin_cs_n;

  spi_pad_wrapper #(
    .DATA_WIDTH(8), .CLOCK_DIVIDER(5), .SPI_MODE(0), .NUM_SLAVES(1),
    .MISO_SYNC_STAGES(1), .LOOPBACK_MODE(1), .LSB_FIRST(0), .ENABLE_PERF(1'b0)
  ) dut_div_min (
    .clk(clk_m), .reset(rst_m), .start(mmin_start), .tx_data(mmin_tx_data), .slave_select(mmin_slave_sel),
    .rx_data(mmin_rx_data), .busy(mmin_busy), .done(mmin_done), .error(mmin_error), .select_error(mmin_sel_err),
    .transfer_active(), .perf_clear(1'b0),
    .perf_txn_count(), .perf_bits_total(), .perf_busy_cycles(),
    .perf_total_cycles(), .perf_last_latency(), .perf_last_sclk_cycles(),
    .perf_reject_count(),
    .clk_slave(clk_s), .reset_slave(rst_s), .slave_tx_data(smin_tx_data), .slave_rx_data(smin_rx_data),
    .slave_rx_valid(smin_rx_valid), .slave_busy(smin_busy), .slave_frame_error(smin_frame_err),
    .pad_sclk(padmin_sclk), .pad_mosi(padmin_mosi), .pad_miso(padmin_miso), .pad_cs_n(padmin_cs_n)
  );

  // ---------------------------------------------------------------------------
  // Verification Helper Tasks
  // ---------------------------------------------------------------------------
  task automatic check_result(
    input string name,
    input logic condition,
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

  // ---------------------------------------------------------------------------
  // Main Verification Sequence
  // ---------------------------------------------------------------------------
  initial begin
    // Setup VCD dumping
    $dumpfile("spi_tb.vcd");
    $dumpvars(0, spi_tb);

    $display("==================================================================");
    $display("       STARTING PARAMETERIZED SPI IP CORE VERIFICATION SUITE       ");
    $display("==================================================================");

    // Initialize all stimulus signals
    m0_start = 0; m0_tx_data = '0; m0_slave_sel = 0; m0_perf_clr = 0; s0_tx_data = '0;
    m1_start = 0; m1_tx_data = '0; m1_slave_sel = 0; s1_tx_data = '0;
    m2_start = 0; m2_tx_data = '0; m2_slave_sel = 0; s2_tx_data = '0;
    m3_start = 0; m3_tx_data = '0; m3_slave_sel = 0; s3_tx_data = '0;
    m16_start = 0; m16_tx_data = '0; m16_slave_sel = 0; s16_tx_data = '0;
    m32_start = 0; m32_tx_data = '0; m32_slave_sel = 0; s32_tx_data = '0;
    lsb_start = 0; lsb_tx_data = '0; lsb_slave_sel = 0; lsb_s_tx_data = '0;
    ms_start = 0; ms_tx_data = '0; ms_slave_sel = 0;
    m1b_start = 0; m1b_tx_data = '0; m1b_slave_sel = 0; s1b_tx_data = '0;
    mmin_start = 0; mmin_tx_data = '0; mmin_slave_sel = 0; smin_tx_data = '0;

    // Apply Synchronous Reset
    rst_m = 1;
    rst_s = 1;
    repeat (5) @(posedge clk_m);
    #1;
    rst_m = 0;
    rst_s = 0;
    repeat (5) @(posedge clk_m);
    #1;

    // =========================================================================
    // TEST 1: Reset & Idle Pin Verification
    // =========================================================================
    $display("\n--- TEST 1: Reset & Idle Pin Levels ---");
    check_result("Mode 0 SCLK Idle", pad0_sclk == 1'b0, "CPOL=0 -> SCLK idle low");
    check_result("Mode 1 SCLK Idle", pad1_sclk == 1'b0, "CPOL=0 -> SCLK idle low");
    check_result("Mode 2 SCLK Idle", pad2_sclk == 1'b1, "CPOL=1 -> SCLK idle high");
    check_result("Mode 3 SCLK Idle", pad3_sclk == 1'b1, "CPOL=1 -> SCLK idle high");
    check_result("Mode 0 CS_N Idle", pad0_cs_n == 1'b1, "CS_N idle deasserted (high)");
    check_result("Mode 0 Busy Idle", m0_busy == 1'b0, "busy=0 after reset");
    check_result("Mode 0 Done Idle", m0_done == 1'b0, "done=0 after reset");

    // =========================================================================
    // TEST 2: SPI Mode 0 Full-Duplex Transfer (CPOL=0, CPHA=0)
    // =========================================================================
    $display("\n--- TEST 2: Mode 0 Full-Duplex Transfer ---");
    s0_tx_data = 8'h5A;
    m0_tx_data = 8'hA5;
    m0_slave_sel = 0;
    @(posedge clk_m); #1;
    m0_start = 1;
    @(posedge clk_m); #1;
    m0_start = 0;

    while (!m0_done) @(posedge clk_m);
    #1;
    check_result("Mode 0 Done/Busy", m0_busy == 1'b0, "busy=0 when done pulses");
    repeat (3) @(posedge clk_s);
    #1;

    check_result("Mode 0 Master RX", m0_rx_data == 8'h5A,
                 $sformatf("Master received: 0x%02X (expected: 0x5A)", m0_rx_data));
    check_result("Mode 0 Slave RX", s0_rx_data == 8'hA5,
                 $sformatf("Slave received:  0x%02X (expected: 0xA5)", s0_rx_data));
    check_result("Mode 0 No Frame Error", s0_frame_err == 1'b0, "No slave frame error");

    // =========================================================================
    // TEST 3: SPI Mode 1 Full-Duplex Transfer (CPOL=0, CPHA=1)
    // =========================================================================
    $display("\n--- TEST 3: Mode 1 Full-Duplex Transfer ---");
    s1_tx_data = 8'hC3;
    m1_tx_data = 8'h3C;
    m1_slave_sel = 0;
    @(posedge clk_m); #1;
    m1_start = 1;
    @(posedge clk_m); #1;
    m1_start = 0;

    while (!m1_done) @(posedge clk_m);
    repeat (3) @(posedge clk_s);
    #1;

    check_result("Mode 1 Master RX", m1_rx_data == 8'hC3,
                 $sformatf("Master received: 0x%02X (expected: 0xC3)", m1_rx_data));
    check_result("Mode 1 Slave RX", s1_rx_data == 8'h3C,
                 $sformatf("Slave received:  0x%02X (expected: 0x3C)", s1_rx_data));

    // =========================================================================
    // TEST 4: SPI Mode 2 Full-Duplex Transfer (CPOL=1, CPHA=0)
    // =========================================================================
    $display("\n--- TEST 4: Mode 2 Full-Duplex Transfer ---");
    s2_tx_data = 8'h0F;
    m2_tx_data = 8'hF0;
    m2_slave_sel = 0;
    @(posedge clk_m); #1;
    m2_start = 1;
    @(posedge clk_m); #1;
    m2_start = 0;

    while (!m2_done) @(posedge clk_m);
    repeat (3) @(posedge clk_s);
    #1;

    check_result("Mode 2 Master RX", m2_rx_data == 8'h0F,
                 $sformatf("Master received: 0x%02X (expected: 0x0F)", m2_rx_data));
    check_result("Mode 2 Slave RX", s2_rx_data == 8'hF0,
                 $sformatf("Slave received:  0x%02X (expected: 0xF0)", s2_rx_data));

    // =========================================================================
    // TEST 5: SPI Mode 3 Full-Duplex Transfer (CPOL=1, CPHA=1)
    // =========================================================================
    $display("\n--- TEST 5: Mode 3 Full-Duplex Transfer ---");
    s3_tx_data = 8'h69;
    m3_tx_data = 8'h96;
    m3_slave_sel = 0;
    @(posedge clk_m); #1;
    m3_start = 1;
    @(posedge clk_m); #1;
    m3_start = 0;

    while (!m3_done) @(posedge clk_m);
    repeat (3) @(posedge clk_s);
    #1;

    check_result("Mode 3 Master RX", m3_rx_data == 8'h69,
                 $sformatf("Master received: 0x%02X (expected: 0x69)", m3_rx_data));
    check_result("Mode 3 Slave RX", s3_rx_data == 8'h96,
                 $sformatf("Slave received:  0x%02X (expected: 0x96)", s3_rx_data));

    // =========================================================================
    // TEST 6: Performance Counter Verification & perf_clear
    // =========================================================================
    $display("\n--- TEST 6: Performance Counter Verification ---");
    // For W=8, D=6:
    // SCLK active cycles = 2*W*D = 2 * 8 * 6 = 96
    // Expected latency   = 2*W*D + D + 2 = 96 + 6 + 2 = 104
    check_result("Perf Transaction Count", m0_txn_cnt == 32'd1,
                 $sformatf("txn_count: %0d (expected 1)", m0_txn_cnt));
    check_result("Perf Bits Total", m0_bits_tot == 32'd8,
                 $sformatf("bits_total: %0d (expected 8)", m0_bits_tot));
    check_result("Perf SCLK Active Cycles", m0_sclk_cyc == 32'd96,
                 $sformatf("SCLK active: %0d (formula: 2*W*D = 96)", m0_sclk_cyc));
    check_result("Perf Latency Formula", m0_lat == 32'd104,
                 $sformatf("latency: %0d (formula: 2*W*D+D+2 = 104)", m0_lat));

    // Test perf_clear (deterministic clock synchronization)
    @(posedge clk_m); #1;
    m0_perf_clr = 1;
    @(posedge clk_m); #1;
    m0_perf_clr = 0;
    @(posedge clk_m); #1;
    check_result("Perf Clear", (m0_txn_cnt == 32'd0) && (m0_bits_tot == 32'd0),
                 "perf_clear reset counters to 0");
    @(negedge clk_m);
    m0_perf_clr = 0;

    // =========================================================================
    // TEST 7: Error Detection & select_error Semantics
    // =========================================================================
    $display("\n--- TEST 7: Error Detection & select_error Semantics ---");

    // 7a. Invalid slave select -> both error and select_error must pulse
    m0_tx_data = 8'h11;
    m0_slave_sel = 1; // Only 1 slave exists (index 0)
    @(posedge clk_m); #1;
    m0_start = 1;
    @(posedge clk_m); #1;
    check_result("Invalid Select: error", m0_error == 1'b1,
                 "error pulsed for invalid slave index");
    check_result("Invalid Select: select_error", m0_sel_err == 1'b1,
                 "select_error pulsed for invalid slave index");
    m0_start = 0;
    m0_slave_sel = 0;
    repeat (2) @(posedge clk_m); #1;

    // 7b. Start while busy -> error must pulse but NOT select_error
    s0_tx_data = 8'h22;
    m0_tx_data = 8'h33;
    @(posedge clk_m); #1;
    m0_start = 1;
    @(posedge clk_m); #1;
    m0_start = 0;
    // Core is now busy
    repeat (5) @(posedge clk_m); #1;
    check_result("Busy Check", m0_busy == 1'b1, "Core is busy");

    // Pulse start while busy with VALID slave select.
    @(negedge clk_m);
    m0_start = 1;
    @(posedge clk_m); #1;
    check_result("Busy Reject: error", m0_error == 1'b1,
                 "error pulsed when start while busy");
    check_result("Busy Reject: NO select_error", m0_sel_err == 1'b0,
                 "select_error NOT pulsed (slave select is valid, rejection due to busy)");
    @(negedge clk_m);
    m0_start = 0;

    while (!m0_done) @(posedge clk_m);
    repeat (3) @(posedge clk_s); #1;

    // =========================================================================
    // TEST 8: Back-to-Back Consecutive Transactions
    // =========================================================================
    $display("\n--- TEST 8: Back-to-Back Streaming Transfers ---");
    for (int i = 0; i < 4; i++) begin
      s0_tx_data = 8'h10 + 8'(i);
      m0_tx_data = 8'h80 + 8'(i);
      @(posedge clk_m); #1;
      m0_start = 1;
      @(posedge clk_m); #1;
      m0_start = 0;
      while (!m0_done) @(posedge clk_m);
      repeat (2) @(posedge clk_s); #1;
      check_result($sformatf("Stream Frame %0d", i),
                   (m0_rx_data == (8'h10 + 8'(i))) && (s0_rx_data == (8'h80 + 8'(i))),
                   $sformatf("Frame %0d loopback verified", i));
    end

    // =========================================================================
    // TEST 9: 16-Bit Parameterized Word Transfer
    // =========================================================================
    $display("\n--- TEST 9: 16-Bit Parameterized Word Transfer ---");
    s16_tx_data = 16'hABCD;
    m16_tx_data = 16'h1234;
    m16_slave_sel = 0;
    @(posedge clk_m); #1;
    m16_start = 1;
    @(posedge clk_m); #1;
    m16_start = 0;

    while (!m16_done) @(posedge clk_m);
    repeat (3) @(posedge clk_s); #1;

    check_result("16-Bit Master RX", m16_rx_data == 16'hABCD,
                 $sformatf("Master received: 0x%04X (expected: 0xABCD)", m16_rx_data));
    check_result("16-Bit Slave RX", s16_rx_data == 16'h1234,
                 $sformatf("Slave received:  0x%04X (expected: 0x1234)", s16_rx_data));

    // =========================================================================
    // TEST 10: 32-Bit Parameterized Word Transfer
    // =========================================================================
    $display("\n--- TEST 10: 32-Bit Parameterized Word Transfer ---");
    s32_tx_data = 32'hDEADBEEF;
    m32_tx_data = 32'hCAFEBABE;
    m32_slave_sel = 0;
    @(posedge clk_m); #1;
    m32_start = 1;
    @(posedge clk_m); #1;
    m32_start = 0;

    while (!m32_done) @(posedge clk_m);
    repeat (3) @(posedge clk_s); #1;

    check_result("32-Bit Master RX", m32_rx_data == 32'hDEADBEEF,
                 $sformatf("Master received: 0x%08X (expected: 0xDEADBEEF)", m32_rx_data));
    check_result("32-Bit Slave RX", s32_rx_data == 32'hCAFEBABE,
                 $sformatf("Slave received:  0x%08X (expected: 0xCAFEBABE)", s32_rx_data));

    // =========================================================================
    // TEST 11: LSB-First Bit Order Transfer
    // =========================================================================
    $display("\n--- TEST 11: LSB-First Bit Order Transfer ---");
    lsb_s_tx_data = 8'hA5;
    lsb_tx_data = 8'h5A;
    lsb_slave_sel = 0;
    @(posedge clk_m); #1;
    lsb_start = 1;
    @(posedge clk_m); #1;
    lsb_start = 0;

    while (!lsb_done) @(posedge clk_m);
    repeat (3) @(posedge clk_s); #1;

    check_result("LSB-First Master RX", lsb_rx_data == 8'hA5,
                 $sformatf("Master received: 0x%02X (expected: 0xA5)", lsb_rx_data));
    check_result("LSB-First Slave RX", lsb_s_rx_data == 8'h5A,
                 $sformatf("Slave received:  0x%02X (expected: 0x5A)", lsb_s_rx_data));

    // =========================================================================
    // TEST 12: Multi-Slave CS Assertion (NUM_SLAVES=4)
    // =========================================================================
    $display("\n--- TEST 12: Multi-Slave CS Assertion ---");
    for (int s = 0; s < 4; s++) begin
      ms_tx_data = 8'hAA;
      ms_slave_sel = 2'(s);
      @(posedge clk_m); #1;
      ms_start = 1;
      @(posedge clk_m); #1;
      ms_start = 0;

      // Wait a few cycles for CS to assert (registered output)
      repeat (3) @(posedge clk_m); #1;

      // Check that exactly one CS is low and it's the right one
      check_result($sformatf("CS%0d Assert", s),
                   ms_cs_n[s] == 1'b0,
                   $sformatf("cs_n[%0d]=0 (asserted)", s));

      // Check no other CS is low
      for (int j = 0; j < 4; j++) begin
        if (j != s) begin
          check_result($sformatf("CS%0d High (sel=%0d)", j, s),
                       ms_cs_n[j] == 1'b1,
                       $sformatf("cs_n[%0d]=1 when slave %0d selected", j, s));
        end
      end

      while (!ms_done) @(posedge clk_m);
      repeat (2) @(posedge clk_m); #1;
    end

    // After all transactions, all CS should be high
    check_result("All CS Idle", ms_cs_n == 4'b1111, "All CS deasserted after transactions");

    // =========================================================================
    // TEST 13: Reset During Active Transaction
    // =========================================================================
    $display("\n--- TEST 13: Reset During Active Transaction ---");
    s0_tx_data = 8'hFF;
    m0_tx_data = 8'hFF;
    @(posedge clk_m); #1;
    m0_start = 1;
    @(posedge clk_m); #1;
    m0_start = 0;

    // Wait until busy, then reset mid-transaction
    repeat (10) @(posedge clk_m); #1;
    check_result("Mid-Txn Busy", m0_busy == 1'b1, "Core busy during transaction");
    rst_m = 1;
    rst_s = 1;
    repeat (3) @(posedge clk_m); #1;
    rst_m = 0;
    rst_s = 0;
    repeat (3) @(posedge clk_m); #1;

    check_result("Post-Reset Busy", m0_busy == 1'b0, "busy=0 after reset");
    check_result("Post-Reset SCLK", pad0_sclk == 1'b0, "SCLK=CPOL after reset");
    check_result("Post-Reset CS", pad0_cs_n == 1'b1, "CS deasserted after reset");

    // Verify normal operation resumes after mid-transaction reset
    s0_tx_data = 8'h42;
    m0_tx_data = 8'h24;
    @(posedge clk_m); #1;
    m0_start = 1;
    @(posedge clk_m); #1;
    m0_start = 0;
    while (!m0_done) @(posedge clk_m);
    repeat (3) @(posedge clk_s); #1;
    check_result("Post-Reset Transfer", m0_rx_data == 8'h42,
                 $sformatf("Post-reset transfer OK: 0x%02X", m0_rx_data));

    // =========================================================================
    // TEST 14: Single-Bit Parameterized Word Transfer (DATA_WIDTH=1)
    // =========================================================================
    $display("\n--- TEST 14: Single-Bit Word Transfer (DATA_WIDTH=1) ---");
    // Test transferring bit '1'
    s1b_tx_data = 1'b1;
    m1b_tx_data = 1'b1;
    m1b_slave_sel = 0;
    @(posedge clk_m); #1;
    m1b_start = 1;
    @(posedge clk_m); #1;
    m1b_start = 0;
    while (!m1b_done) @(posedge clk_m);
    repeat (3) @(posedge clk_s); #1;
    check_result("1-Bit Master RX (bit 1)", m1b_rx_data == 1'b1, "Master received 1'b1");
    check_result("1-Bit Slave RX (bit 1)",  s1b_rx_data == 1'b1, "Slave received 1'b1");

    // Test transferring bit '0'
    s1b_tx_data = 1'b0;
    m1b_tx_data = 1'b0;
    @(posedge clk_m); #1;
    m1b_start = 1;
    @(posedge clk_m); #1;
    m1b_start = 0;
    while (!m1b_done) @(posedge clk_m);
    repeat (3) @(posedge clk_s); #1;
    check_result("1-Bit Master RX (bit 0)", m1b_rx_data == 1'b0, "Master received 1'b0");
    check_result("1-Bit Slave RX (bit 0)",  s1b_rx_data == 1'b0, "Slave received 1'b0");

    // =========================================================================
    // TEST 15: Minimum Legal Clock Divider Boundary (CLOCK_DIVIDER=5)
    // =========================================================================
    $display("\n--- TEST 15: Minimum Legal Clock Divider Boundary ---");
    smin_tx_data = 8'hE7;
    mmin_tx_data = 8'h7E;
    mmin_slave_sel = 0;
    @(posedge clk_m); #1;
    mmin_start = 1;
    @(posedge clk_m); #1;
    mmin_start = 0;
    while (!mmin_done) @(posedge clk_m);
    repeat (3) @(posedge clk_s); #1;
    check_result("Min Divider Master RX", mmin_rx_data == 8'hE7,
                 $sformatf("Master received: 0x%02X at D=5", mmin_rx_data));
    check_result("Min Divider Slave RX", smin_rx_data == 8'h7E,
                 $sformatf("Slave received:  0x%02X at D=5", smin_rx_data));
    check_result("Min Divider Frame Error", smin_frame_err == 1'b0, "No frame error at D=5");

    // =========================================================================
    // TEST 16: Reset Lifecycle Verification (Before & After Transfer)
    // =========================================================================
    $display("\n--- TEST 16: Reset Lifecycle Verification ---");

    // 16a. Reset-Before-Transfer: assert start while reset=1
    rst_m = 1;
    @(posedge clk_m); #1;
    m0_start = 1;
    @(posedge clk_m); #1;
    m0_start = 0;
    repeat (3) @(posedge clk_m); #1;
    check_result("Reset-Before Busy Inactive", m0_busy == 1'b0, "Core stays idle during reset");
    check_result("Reset-Before CS Inactive", pad0_cs_n == 1'b1, "CS stays high during reset");
    check_result("Reset-Before Done Inactive", m0_done == 1'b0, "Done stays low during reset");

    // Release reset and verify clean transfer execution
    rst_m = 0;
    repeat (3) @(posedge clk_m); #1;
    s0_tx_data = 8'h77;
    m0_tx_data = 8'h88;
    @(posedge clk_m); #1;
    m0_start = 1;
    @(posedge clk_m); #1;
    m0_start = 0;
    while (!m0_done) @(posedge clk_m);
    repeat (3) @(posedge clk_s); #1;
    check_result("Reset-Before Recovery RX", m0_rx_data == 8'h77, "Transfer OK after reset release");

    // 16b. Reset-After-Transfer: completed transfer, then pulse reset
    rst_m = 1;
    @(posedge clk_m); #1;
    rst_m = 0;
    @(posedge clk_m); #1;
    check_result("Reset-After Busy Quiescent", m0_busy == 1'b0, "busy=0 after post-transfer reset");
    check_result("Reset-After Done Quiescent", m0_done == 1'b0, "done=0 after post-transfer reset");
    check_result("Reset-After CS Quiescent", pad0_cs_n == 1'b1, "CS=1 after post-transfer reset");
    check_result("Reset-After SCLK Quiescent", pad0_sclk == 1'b0, "SCLK=CPOL after post-transfer reset");

    // =========================================================================
    // Final Summary Report
    // =========================================================================
    $display("\n==================================================================");
    $display("               SPI IP VERIFICATION SUMMARY REPORT                 ");
    $display("==================================================================");
    $display(" Total Tests Executed : %0d", total_tests);
    $display(" Tests Passed         : %0d", pass_count);
    $display(" Tests Failed         : %0d", fail_count);
    if (fail_count == 0) begin
      $display(" Final Status         : [PASSED] ALL VERIFICATION CHECKS PASSED!");
    end else begin
      $display(" Final Status         : [FAILED] SOME CHECKS FAILED!");
    end
    $display("==================================================================\n");

    if (fail_count > 0) $fatal(1, "Testbench FAILED");
    $finish;
  end

  // Watchdog timeout to prevent infinite simulation loops
  initial begin
    repeat (TIMEOUT_CYCLES) @(posedge clk_m);
    $display("\n[ERROR] Watchdog timer expired (%0d cycles)! Simulation aborted.", TIMEOUT_CYCLES);
    $fatal(1, "Watchdog timeout");
  end

endmodule
