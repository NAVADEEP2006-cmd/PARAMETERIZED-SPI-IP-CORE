# ==============================================================================
# spi_master_top.xdc - Core Timing Constraints for SPI Master IP Core
#
# Primary Clock Definition:
#   Clock:            clk
#   Target Frequency: 50.000 MHz
#   Clock Period:     20.000 ns (50% duty cycle: 0.000 ns rise, 10.000 ns fall)
#
# Architectural Context:
#   This constraint sets the IP-level timing budget for the core synchronous
#   clock domain. It matches the specification documented in architecture.md
#   and verified across the testbench suite.
#
# Note:
#   Board-specific physical pin locations (PACKAGE_PIN), I/O electrical standards
#   (IOSTANDARD), and board trace delay constraints must be defined in separate
#   board-level integration constraint files when targeting a physical board.
# ==============================================================================

create_clock -period 20.000 -name clk -waveform {0.000 10.000} [get_ports clk]
