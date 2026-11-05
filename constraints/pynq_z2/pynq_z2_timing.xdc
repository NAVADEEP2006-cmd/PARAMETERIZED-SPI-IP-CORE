# ==============================================================================
# pynq_z2_timing.xdc - Core IP Out-of-Context (OOC) Timing Constraints
#
# Target Architecture: AMD Zynq-7000 (xc7z020clg400-1) / TUL PYNQ-Z2
# Target Module:       spi_master_top (or spi_pad_wrapper in OOC mode)
#
# Primary Synchronous Clock Definition:
#   Clock:            clk
#   Target Frequency: 50.000 MHz
#   Clock Period:     20.000 ns (50% duty cycle: 0.000 ns rise, 10.000 ns fall)
#
# Architectural Context:
#   This constraint specifies the synchronous timing budget for Out-of-Context (OOC)
#   synthesis and implementation of the standalone SPI Master IP Core.
#   - In a complete Zynq SoC design, this 50 MHz clock domain is typically
#     supplied by the Processing System (FCLK_CLK0 via AXI-SPI bridge).
#   - Note: No MMCM or Clocking Wizard IP is instantiated within this IP baseline;
#     physical board demonstration uses spi_pynq_z2_top with the 125 MHz clock
#     constrained in pynq_z2_pins.xdc.
# ==============================================================================

create_clock -period 20.000 -name clk -waveform {0.000 10.000} [get_ports clk]
