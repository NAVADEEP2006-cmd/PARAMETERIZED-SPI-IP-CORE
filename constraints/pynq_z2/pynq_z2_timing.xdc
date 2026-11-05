# ==============================================================================
# pynq_z2_timing.xdc - Core IP Timing Constraints for SPI IP Core
#
# Target Architecture: AMD Zynq-7000 (xc7z020clg400-1) / TUL PYNQ-Z2
#
# Primary Synchronous Clock Definition:
#   Clock:            clk
#   Target Frequency: 50.000 MHz
#   Clock Period:     20.000 ns (50% duty cycle: 0.000 ns rise, 10.000 ns fall)
#
# Architectural Context:
#   This constraint specifies the synchronous clock timing budget for out-of-context
#   (OOC) IP core synthesis and implementation. When integrated into the full
#   PYNQ-Z2 board system with the 125 MHz onboard oscillator (pin H16), an MMCM /
#   Clocking Wizard IP generates this 50 MHz core clock domain.
# ==============================================================================

create_clock -period 20.000 -name clk -waveform {0.000 10.000} [get_ports clk]
