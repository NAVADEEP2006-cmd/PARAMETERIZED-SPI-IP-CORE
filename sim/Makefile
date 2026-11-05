# ==============================================================================
# Parameterized SPI IP Core - Simulation & Verification Makefile
# ==============================================================================

VERILATOR ?= verilator
IVERILOG  ?= iverilog
VVP       ?= vvp
PYTHON    ?= python3

RTL_DIR = ../rtl
TB_DIR  = ../tb

# RTL filelist excluding board-level wrapper for core simulation & lint
RTL_SRCS = $(RTL_DIR)/common/spi_pkg.sv \
           $(RTL_DIR)/master/spi_clock_gen.sv \
           $(RTL_DIR)/master/spi_bit_counter.sv \
           $(RTL_DIR)/master/spi_tx_shift.sv \
           $(RTL_DIR)/master/spi_rx_shift.sv \
           $(RTL_DIR)/master/spi_cs_ctrl.sv \
           $(RTL_DIR)/master/spi_master_fsm.sv \
           $(RTL_DIR)/master/spi_perf_counters.sv \
           $(RTL_DIR)/master/spi_master.sv \
           $(RTL_DIR)/master/spi_master_top.sv \
           $(RTL_DIR)/master/spi_top.sv \
           $(RTL_DIR)/slave/spi_slave.sv \
           $(RTL_DIR)/slave/spi_slave_top.sv \
           $(RTL_DIR)/common/spi_pad_wrapper.sv

RTL_BOARD = $(RTL_DIR)/board/spi_pynq_z2_top.sv

TB_SRCS = $(TB_DIR)/integration/spi_tb.sv

.PHONY: all lint unit integration sim test-clock-gen test-bit-counter test-cs-ctrl test-shift-regs test-master-fsm clean wave

all: lint unit integration

# Lint RTL and TB using Verilator
lint:
	@echo "--- Running Verilator RTL Lint ---"
	$(VERILATOR) --lint-only -Wall -sv $(RTL_SRCS) --top-module spi_pad_wrapper
	@echo "--- Running Verilator Board Top Lint ---"
	$(VERILATOR) --lint-only -Wall -Wno-TIMESCALEMOD -Wno-PINCONNECTEMPTY -sv $(RTL_SRCS) $(RTL_BOARD) --top-module spi_pynq_z2_top
	@echo "--- Running Verilator Full Lint ---"
	$(VERILATOR) --lint-only --timing -Wall -Wno-TIMESCALEMOD -Wno-PINCONNECTEMPTY -sv $(RTL_SRCS) $(TB_SRCS) --top-module spi_tb
	@echo "--- Verilator Lint Passed with 0 errors! ---"

# Modular Unit Tests
test-clock-gen:
	@echo "--- Running Clock Generator Unit Test ---"
	$(IVERILOG) -g2012 -Wall -s tb_spi_clock_gen -o tb_spi_clock_gen.out $(RTL_DIR)/common/spi_pkg.sv $(RTL_DIR)/master/spi_clock_gen.sv $(TB_DIR)/unit/tb_spi_clock_gen.sv
	$(VVP) tb_spi_clock_gen.out

test-bit-counter:
	@echo "--- Running Bit Counter Unit Test ---"
	$(IVERILOG) -g2012 -Wall -s tb_spi_bit_counter -o tb_spi_bit_counter.out $(RTL_DIR)/common/spi_pkg.sv $(RTL_DIR)/master/spi_bit_counter.sv $(TB_DIR)/unit/tb_spi_bit_counter.sv
	$(VVP) tb_spi_bit_counter.out

test-cs-ctrl:
	@echo "--- Running Chip-Select Controller Unit Test ---"
	$(IVERILOG) -g2012 -Wall -s tb_spi_cs_ctrl -o tb_spi_cs_ctrl.out $(RTL_DIR)/common/spi_pkg.sv $(RTL_DIR)/master/spi_cs_ctrl.sv $(TB_DIR)/unit/tb_spi_cs_ctrl.sv
	$(VVP) tb_spi_cs_ctrl.out

test-shift-regs:
	@echo "--- Running Shift Registers Unit Test ---"
	$(IVERILOG) -g2012 -Wall -s tb_spi_shift_regs -o tb_spi_shift_regs.out $(RTL_DIR)/master/spi_tx_shift.sv $(RTL_DIR)/master/spi_rx_shift.sv $(TB_DIR)/unit/tb_spi_shift_regs.sv
	$(VVP) tb_spi_shift_regs.out

test-master-fsm:
	@echo "--- Running Master FSM Unit Test ---"
	$(IVERILOG) -g2012 -Wall -s tb_spi_master_fsm -o tb_spi_master_fsm.out $(RTL_DIR)/master/spi_master_fsm.sv $(TB_DIR)/unit/tb_spi_master_fsm.sv
	$(VVP) tb_spi_master_fsm.out

unit: test-clock-gen test-bit-counter test-cs-ctrl test-shift-regs test-master-fsm
	@echo "--- All 5 Unit Testbenches Passed! ---"

# Full Integration Test using Icarus Verilog
integration:
	@echo "--- Compiling and Running Complete Integration Test with Icarus Verilog ---"
	$(IVERILOG) -g2012 -Wall -s spi_tb -o spi_tb_sim.out $(RTL_SRCS) $(TB_SRCS)
	$(VVP) spi_tb_sim.out

# Full Integration Test using Verilator
sim:
	@echo "--- Compiling and Running with Verilator (--binary --timing) ---"
	$(VERILATOR) --binary --timing -Wall -Wno-TIMESCALEMOD -Wno-PINCONNECTEMPTY -sv $(RTL_SRCS) $(TB_SRCS) --top-module spi_tb --trace
	./obj_dir/Vspi_tb

# Open waveform in GTKWave
wave:
	gtkwave spi_tb.vcd &

# Clean build artifacts
clean:
	rm -rf obj_dir *.vcd *.out *.log
