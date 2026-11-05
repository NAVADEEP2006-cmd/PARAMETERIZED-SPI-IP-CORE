# ==============================================================================
# Parameterized SPI IP Core - Simulation & Lint Makefile
# ==============================================================================

VERILATOR ?= verilator
IVERILOG  ?= iverilog
VVP       ?= vvp

RTL_DIR = ../rtl
TB_DIR  = ../tb

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

TB_SRCS = $(TB_DIR)/integration/spi_tb.sv

.PHONY: all lint sim sim-binary sim-iverilog clean wave

all: lint

# Lint RTL and TB using Verilator
lint:
	@echo "--- Running Verilator RTL Lint ---"
	$(VERILATOR) --lint-only -Wall -sv $(RTL_SRCS) --top-module spi_pad_wrapper
	@echo "--- Running Verilator Full Lint ---"
	$(VERILATOR) --lint-only --timing -Wall -Wno-TIMESCALEMOD -Wno-PINCONNECTEMPTY -sv $(RTL_SRCS) $(TB_SRCS) --top-module spi_tb
	@echo "--- Verilator Lint Passed with 0 errors! ---"

# Simulation using modern Verilator (v5+ with --timing and --binary)
sim: sim-binary

sim-binary:
	@echo "--- Compiling and Running with Verilator (--binary --timing) ---"
	$(VERILATOR) --binary --timing -Wall -Wno-TIMESCALEMOD -Wno-PINCONNECTEMPTY -sv $(RTL_SRCS) $(TB_SRCS) --top-module spi_tb --trace
	./obj_dir/Vspi_tb

# Simulation fallback using Icarus Verilog
sim-iverilog:
	@echo "--- Compiling and Running with Icarus Verilog ---"
	$(IVERILOG) -g2012 -Wall -o spi_tb_sim.out $(RTL_SRCS) $(TB_SRCS)
	$(VVP) spi_tb_sim.out

# Open waveform in GTKWave
wave:
	gtkwave spi_tb.vcd &

# Clean build artifacts
clean:
	rm -rf obj_dir *.vcd *.out *.log
