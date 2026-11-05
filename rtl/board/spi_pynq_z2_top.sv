// -----------------------------------------------------------------------------
// spi_pynq_z2_top.sv  -  Dedicated Hardware Demonstration Top for TUL PYNQ-Z2
//
// Target Board:       TUL PYNQ-Z2 (AMD Zynq-7020 xc7z020clg400-1)
// Target Connectors:  Pmod B (Header JB) & Onboard User I/O
//
// Architectural Role:
//   This module is a physical demonstration wrapper for the Parameterized SPI IP Core.
//   It bridges the physical FPGA pins (125 MHz Ethernet PHY clock, pushbuttons,
//   switches, LEDs, and Pmod B SPI pins) to the reusable 'spi_master_top' core.
//
// Clock Architecture:
//   - Physical Reference Clock: 125.0 MHz single-ended clock on pin H16 (Bank 35)
//     sourced from the onboard Realtek RTL8211E-VL Ethernet PHY (U5, pin 40 CLK125).
//   - Core Operating Frequency: Operates synchronously on the 125 MHz reference clock.
//   - SCLK Generation: With CLOCK_DIVIDER = 15, SCLK = 125 MHz / (2 * 15) = 4.167 MHz.
//     This complies with Pmod unshielded flying-lead signal integrity requirements (< 5 MHz).
//   - Note: In a full Zynq PS+PL production design, a 50 MHz clock would typically be
//     supplied by the Processing System (FCLK_CLK0) via an AXI-to-SPI bridge.
//     No MMCM or Clocking Wizard IP is instantiated in this standalone RTL baseline.
//
// Pin Allocation Summary:
//   - Clock & Reset:
//       sysclk       -> H16 (125 MHz PL reference clock, Bank 35, LVCMOS33)
//       reset_btn    -> D19 (Pushbutton BTN0, Bank 35, LVCMOS33, active-high)
//       start_btn    -> D20 (Pushbutton BTN1, Bank 35, LVCMOS33, active-high)
//   - Transaction Controls:
//       sw_slave_sel -> M20 (SW0), M19 (SW1) (Bank 35, LVCMOS33)
//   - SPI Bus on Pmod B (Bank 34, LVCMOS33, 8mA SLOW):
//       pad_cs_n[0]  -> W14 (Pin 1, JB1_P)
//       pad_mosi     -> Y14 (Pin 2, JB1_N)
//       pad_miso     -> T11 (Pin 3, JB2_P, internal PULLUP)
//       pad_sclk     -> T10 (Pin 4, JB2_N)
//       pad_cs_n[1]  -> V16 (Pin 7, JB3_P)
//       pad_cs_n[2]  -> W16 (Pin 8, JB3_N)
//       pad_cs_n[3]  -> V12 (Pin 9, JB4_P)
//   - Status LEDs (Bank 34, LVCMOS33):
//       led_busy     -> R14 (LD0)
//       led_done     -> P14 (LD1)
//       led_error    -> N16 (LD2)
//       led_active   -> M14 (LD3 - transfer active / heartbeat)
// -----------------------------------------------------------------------------

module spi_pynq_z2_top
  import spi_pkg::*;
#(
  parameter int DATA_WIDTH    = 8,
  parameter int CLOCK_DIVIDER = 15, // 125 MHz / (2 * 15) = 4.167 MHz SCLK
  parameter int SPI_MODE      = 0,
  parameter int NUM_SLAVES    = 4,
  parameter bit LSB_FIRST     = 1'b0
)(
  // Physical Board Clock & User Controls
  input  logic                      sysclk,         // 125 MHz PL Reference Clock (H16)
  input  logic                      reset_btn,      // BTN0 (D19) - Active-high reset
  input  logic                      start_btn,      // BTN1 (D20) - Trigger transaction
  input  logic [1:0]                sw_slave_sel,   // SW[1:0] (M20, M19) - Slave selection

  // Physical SPI Master I/O on Pmod B (Header JB)
  output logic                      pad_sclk,       // Pmod B Pin 4 (T10)
  output logic                      pad_mosi,       // Pmod B Pin 2 (Y14)
  input  logic                      pad_miso,       // Pmod B Pin 3 (T11)
  output logic [NUM_SLAVES-1:0]     pad_cs_n,       // Pmod B Pins 1, 7, 8, 9

  // Diagnostic Status LEDs
  output logic                      led_busy,       // LD0 (R14) - Core Busy
  output logic                      led_done,       // LD1 (P14) - Transfer Complete
  output logic                      led_error,      // LD2 (N16) - Transaction / Select Error
  output logic                      led_active      // LD3 (M14) - Transfer Active Heartbeat
);

  // ---------------------------------------------------------------------------
  // 1. Synchronizers and Edge Detectors for Pushbuttons
  // ---------------------------------------------------------------------------
  logic [1:0] rst_sync;
  logic       core_reset;

  always_ff @(posedge sysclk) begin
    rst_sync <= {rst_sync[0], reset_btn};
  end
  assign core_reset = rst_sync[1];

  logic [1:0] start_sync;
  logic       start_d;
  logic       start_pulse;

  always_ff @(posedge sysclk) begin
    if (core_reset) begin
      start_sync  <= 2'b00;
      start_d     <= 1'b0;
      start_pulse <= 1'b0;
    end else begin
      start_sync  <= {start_sync[0], start_btn};
      start_d     <= start_sync[1];
      start_pulse <= start_sync[1] & ~start_d; // 1-cycle edge detect
    end
  end

  // Synchronize slave select switch inputs
  logic [1:0] sw_sync_0, sw_sync_1;
  always_ff @(posedge sysclk) begin
    sw_sync_0 <= sw_slave_sel;
    sw_sync_1 <= sw_sync_0;
  end

  // ---------------------------------------------------------------------------
  // 2. Demonstration Transaction Generator
  // ---------------------------------------------------------------------------
  // Increments an 8-bit test pattern each time start_btn is pressed
  logic [DATA_WIDTH-1:0] tx_data_reg;
  /* verilator lint_off UNUSEDSIGNAL */
  logic [DATA_WIDTH-1:0] rx_data_wire;
  /* verilator lint_on UNUSEDSIGNAL */
  logic                  core_start;
  logic                  core_busy;
  logic                  core_done;
  logic                  core_error;
  logic                  core_select_error;
  logic                  core_transfer_active;

  always_ff @(posedge sysclk) begin
    if (core_reset) begin
      tx_data_reg <= 8'hA5; // Default recognizable initial test payload
      core_start  <= 1'b0;
    end else begin
      core_start  <= 1'b0;
      if (start_pulse && !core_busy) begin
        core_start  <= 1'b1;
        tx_data_reg <= tx_data_reg + 8'h01;
      end
    end
  end

  // ---------------------------------------------------------------------------
  // 3. Reusable Parameterized SPI Master Core Instantiation
  // ---------------------------------------------------------------------------
  spi_master_top #(
    .DATA_WIDTH       (DATA_WIDTH),
    .CLOCK_DIVIDER    (CLOCK_DIVIDER),
    .SPI_MODE         (SPI_MODE),
    .NUM_SLAVES       (NUM_SLAVES),
    .MISO_SYNC_STAGES (2),
    .ENABLE_PERF      (1'b0), // Omit perf counters for minimum board resource footprint
    .LSB_FIRST        (LSB_FIRST)
  ) u_spi_master (
    .clk              (sysclk),
    .reset            (core_reset),
    .start            (core_start),
    .tx_data          (tx_data_reg),
    .slave_select     (sw_sync_1[spi_idx_w(NUM_SLAVES)-1:0]),
    .rx_data          (rx_data_wire),
    .busy             (core_busy),
    .done             (core_done),
    .error            (core_error),
    .select_error     (core_select_error),
    .transfer_active  (core_transfer_active),
    .sclk             (pad_sclk),
    .mosi             (pad_mosi),
    .miso             (pad_miso),
    .cs_n             (pad_cs_n),
    .perf_clear       (1'b0),
    .perf_txn_count   (),
    .perf_bits_total  (),
    .perf_busy_cycles (),
    .perf_total_cycles(),
    .perf_last_latency(),
    .perf_last_sclk_cycles(),
    .perf_reject_count()
  );

  // ---------------------------------------------------------------------------
  // 4. Output Status LED Drive & Activity Pulse Extension
  // ---------------------------------------------------------------------------
  // Pulse-stretch 'done' and 'error' so brief events are clearly visible to human eye
  logic [27:0] done_stretch_cnt;
  logic        done_led_reg;
  logic [27:0] err_stretch_cnt;
  logic        err_led_reg;

  always_ff @(posedge sysclk) begin
    if (core_reset) begin
      done_stretch_cnt <= 28'd0;
      done_led_reg     <= 1'b0;
      err_stretch_cnt  <= 28'd0;
      err_led_reg      <= 1'b0;
    end else begin
      // Done stretch: ~100 ms at 125 MHz (12,500,000 cycles)
      if (core_done) begin
        done_stretch_cnt <= 28'd12_500_000;
        done_led_reg     <= 1'b1;
      end else if (done_stretch_cnt > 28'd0) begin
        done_stretch_cnt <= done_stretch_cnt - 28'd1;
      end else begin
        done_led_reg     <= 1'b0;
      end

      // Error stretch: ~250 ms at 125 MHz (31,250,000 cycles)
      if (core_error || core_select_error) begin
        err_stretch_cnt <= 28'd31_250_000;
        err_led_reg     <= 1'b1;
      end else if (err_stretch_cnt > 28'd0) begin
        err_stretch_cnt <= err_stretch_cnt - 28'd1;
      end else begin
        err_led_reg     <= 1'b0;
      end
    end
  end

  assign led_busy   = core_busy;
  assign led_done   = done_led_reg;
  assign led_error  = err_led_reg;
  assign led_active = core_transfer_active;

endmodule
