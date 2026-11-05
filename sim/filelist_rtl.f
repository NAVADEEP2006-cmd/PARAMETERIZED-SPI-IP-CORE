# Parameterized SPI IP Core - RTL Filelist
# Compile spi_pkg.sv FIRST, followed by submodules and top levels

../rtl/common/spi_pkg.sv
../rtl/master/spi_clock_gen.sv
../rtl/master/spi_bit_counter.sv
../rtl/master/spi_tx_shift.sv
../rtl/master/spi_rx_shift.sv
../rtl/master/spi_cs_ctrl.sv
../rtl/master/spi_master_fsm.sv
../rtl/master/spi_perf_counters.sv
../rtl/master/spi_master.sv
../rtl/master/spi_master_top.sv
../rtl/master/spi_top.sv
../rtl/slave/spi_slave.sv
../rtl/slave/spi_slave_top.sv
../rtl/common/spi_pad_wrapper.sv
