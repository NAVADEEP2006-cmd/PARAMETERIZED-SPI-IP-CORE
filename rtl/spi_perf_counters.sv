// -----------------------------------------------------------------------------
// spi_perf_counters.sv  -  Optional performance / diagnostic measurement hooks
//
// All counters are 32-bit, free-running, wrap on overflow, cleared by `clear`
// (or reset). Clearing during a transaction corrupts that one transaction's
// "last_*" values only.
//   txn_count      completed transactions (done pulses)
//   bits_total     txn_count * DATA_WIDTH
//   busy_cycles    cycles with busy=1          -> utilization = busy/total
//   total_cycles   cycles since clear          (observation window)
//   last_latency   cycles of the last transaction from S_SELECT entry to done
//                  pulse (inclusive). The FSM sets busy=0 and done=1 in the
//                  same S_DONE cycle, so last_latency includes all active
//                  states + the done cycle itself.
//                  Expected value: 2*W*D + D + 2  (see docs)
//   last_sclk_cycles cycles SCLK was toggling in the last transaction = 2*W*D
//                  -> CS/FSM overhead = last_latency - last_sclk_cycles
//   reject_count   rejected start requests (error pulses)
// ENABLE=0 ties every output to 0 and generates no logic.
//
// Note: These are performance/diagnostic counters, not QoS arbitration logic.
// They measure and report timing characteristics but do not enforce any
// quality-of-service guarantees or priority schemes.
// -----------------------------------------------------------------------------
module spi_perf_counters #(
  parameter bit ENABLE     = 1'b1,
  parameter int DATA_WIDTH = 8
)(
  input  logic        clk,
  input  logic        reset,
  input  logic        clear,
  input  logic        busy,
  input  logic        done,
  input  logic        transfer_active,
  input  logic        start_error,
  output logic [31:0] txn_count,
  output logic [31:0] bits_total,
  output logic [31:0] busy_cycles,
  output logic [31:0] total_cycles,
  output logic [31:0] last_latency,
  output logic [31:0] last_sclk_cycles,
  output logic [31:0] reject_count
);
  if (ENABLE) begin : g_perf
    logic [31:0] lat_cnt, xfer_cnt;

    always_ff @(posedge clk) begin
      if (reset || clear) begin
        txn_count <= '0; bits_total <= '0; busy_cycles <= '0; total_cycles <= '0;
        last_latency <= '0; last_sclk_cycles <= '0; reject_count <= '0;
        lat_cnt <= '0; xfer_cnt <= '0;
      end else begin
        total_cycles <= total_cycles + 32'd1;
        if (busy) begin
          busy_cycles <= busy_cycles + 32'd1;
          lat_cnt     <= lat_cnt + 32'd1;
        end else begin
          lat_cnt  <= '0;
          xfer_cnt <= '0;
        end
        if (transfer_active) xfer_cnt <= xfer_cnt + 32'd1;
        if (done) begin
          txn_count        <= txn_count + 32'd1;
          bits_total       <= bits_total + 32'(DATA_WIDTH);
          last_latency     <= lat_cnt + 32'd1;   // include the done cycle itself
          last_sclk_cycles <= xfer_cnt;
        end
        if (start_error) reject_count <= reject_count + 32'd1;
      end
    end
  end else begin : g_off
    /* verilator lint_off UNUSEDSIGNAL */
    logic _unused = &{1'b0, clk, reset, clear, busy, done, transfer_active, start_error};
    /* verilator lint_on UNUSEDSIGNAL */
    assign txn_count = '0;   assign bits_total = '0;
    assign busy_cycles = '0; assign total_cycles = '0;
    assign last_latency = '0; assign last_sclk_cycles = '0;
    assign reject_count = '0;
  end
endmodule
