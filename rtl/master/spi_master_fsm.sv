// -----------------------------------------------------------------------------
// spi_master_fsm.sv  -  Master transaction control FSM
//
// States (reset state = S_IDLE)
//   S_IDLE     : wait for start_req. On start_req: `accept` (=load) pulses,
//                TX register / bit counter / slave-select are loaded, -> S_SELECT
//   S_SELECT   : one cycle; cs_active=1 so the registered cs_n asserts next cycle
//   S_TRANSFER : run=1, sclk_en=1. SCLK toggles 2*DATA_WIDTH times.
//                Leaves on `xfer_last` (last trailing edge = SCLK back to idle)
//   S_DESELECT : run=1, sclk_en=0. CS is held for one more half-period (tick)
//                -> `capture` pulses on that tick to latch RX data, -> S_DONE
//   S_DONE     : one cycle: done=1. cs_active=0 (CS releases), TX cleared. -> S_IDLE
//
// The spec lifecycle IDLE->START->SELECT->LOAD->TRANSFER->FINAL BIT->COMPLETE->
// DESELECT->IDLE maps as: START+LOAD happen on the IDLE->SELECT transition,
// FINAL BIT is the xfer_last condition, COMPLETE is S_DONE.
// Start while not IDLE is simply not looked at (ignored).
// -----------------------------------------------------------------------------
module spi_master_fsm (
  input  logic clk,
  input  logic reset,
  input  logic start_req,     // start && valid slave_select
  input  logic tick,          // half-period strobe from clock gen
  input  logic xfer_last,     // last trailing edge occurring this cycle
  output logic accept,        // start accepted (1 cycle, in S_IDLE)
  output logic cs_active,
  output logic run,
  output logic sclk_en,
  output logic capture,
  output logic tx_clear,
  output logic busy,
  output logic done
);
  typedef enum logic [2:0] {
    S_IDLE, S_SELECT, S_TRANSFER, S_DESELECT, S_DONE
  } state_t;

  state_t state, next_state;

  always_ff @(posedge clk) begin
    if (reset) state <= S_IDLE;
    else       state <= next_state;
  end

  always_comb begin
    next_state = state;
    accept     = 1'b0;
    unique case (state)
      S_IDLE:     if (start_req) begin accept = 1'b1; next_state = S_SELECT; end
      S_SELECT:   next_state = S_TRANSFER;
      S_TRANSFER: if (xfer_last) next_state = S_DESELECT;
      S_DESELECT: if (tick)      next_state = S_DONE;
      S_DONE:     next_state = S_IDLE;
      default:    next_state = S_IDLE;
    endcase
  end

  assign cs_active = (state == S_SELECT) || (state == S_TRANSFER) || (state == S_DESELECT);
  assign run       = (state == S_TRANSFER) || (state == S_DESELECT);
  assign sclk_en   = (state == S_TRANSFER);
  assign capture   = (state == S_DESELECT) && tick;
  assign tx_clear  = (state == S_DONE);
  assign busy      = (state != S_IDLE) && (state != S_DONE);
  assign done      = (state == S_DONE);
endmodule
