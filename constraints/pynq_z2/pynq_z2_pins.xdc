# ==============================================================================
# pynq_z2_pins.xdc - Physical Pin Constraints for TUL PYNQ-Z2 (Zynq-7020 CLG400)
#
# Target Board:       TUL PYNQ-Z2 (xc7z020clg400-1)
# Documentation Ref:  PYNQ-Z2 User Manual v1.0 / TUL PYNQ-Z2 Schematic Rev C
#
# Hardware Integration Status: PROPOSED (Pending physical laboratory validation)
#
# Connector & Signal Allocation:
#   - Pmod B (Header JB): Primary external SPI peripheral connector
#       Pin 1 (JB1_P) -> W14 -> pad_cs_n[0]  (Active-low Chip Select 0 / Slave 0)
#       Pin 2 (JB1_N) -> Y14 -> pad_mosi     (Master Out Slave In)
#       Pin 3 (JB2_P) -> T11 -> pad_miso     (Master In Slave Out)
#       Pin 4 (JB2_N) -> T10 -> pad_sclk     (SPI Serial Clock)
#       Pin 7 (JB3_P) -> V16 -> pad_cs_n[1]  (Active-low Chip Select 1 / Slave 1)
#       Pin 8 (JB3_N) -> W16 -> pad_cs_n[2]  (Active-low Chip Select 2 / Slave 2)
#       Pin 9 (JB4_P) -> V12 -> pad_cs_n[3]  (Active-low Chip Select 3 / Slave 3)
#       Pin 5, 11     -> GND
#       Pin 6, 12     -> VCC (3.3V)
#
#   - Onboard System Clock & Reset:
#       Pin H16       -> sysclk (125.0 MHz onboard oscillator)
#       Pin D19       -> btn[0] (Pushbutton 0 - synchronous reset input)
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Onboard Clock (125 MHz Oscillator -> H16)
# ------------------------------------------------------------------------------
set_property PACKAGE_PIN H16 [get_ports sysclk]
set_property IOSTANDARD LVCMOS33 [get_ports sysclk]
create_clock -period 8.000 -name sysclk -waveform {0.000 4.000} [get_ports sysclk]

# ------------------------------------------------------------------------------
# 2. Reset Button (Pushbutton BTN0 -> D19)
# ------------------------------------------------------------------------------
set_property PACKAGE_PIN D19 [get_ports reset]
set_property IOSTANDARD LVCMOS33 [get_ports reset]

# ------------------------------------------------------------------------------
# 3. Pmod B (Header JB) - Physical SPI Master Signals (LVCMOS33)
# ------------------------------------------------------------------------------
# Pin 1: Chip Select 0 (JB1_P)
set_property PACKAGE_PIN W14 [get_ports {pad_cs_n[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {pad_cs_n[0]}]

# Pin 2: MOSI (JB1_N)
set_property PACKAGE_PIN Y14 [get_ports pad_mosi]
set_property IOSTANDARD LVCMOS33 [get_ports pad_mosi]

# Pin 3: MISO with internal pull-up (JB2_P)
set_property PACKAGE_PIN T11 [get_ports pad_miso]
set_property IOSTANDARD LVCMOS33 [get_ports pad_miso]
set_property PULLUP true [get_ports pad_miso]

# Pin 4: SCLK (JB2_N)
set_property PACKAGE_PIN T10 [get_ports pad_sclk]
set_property IOSTANDARD LVCMOS33 [get_ports pad_sclk]

# Multi-slave expansions (Optional JB pins 7, 8, 9)
set_property PACKAGE_PIN V16 [get_ports {pad_cs_n[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {pad_cs_n[1]}]

# ------------------------------------------------------------------------------
# 4. Slew Rate and Drive Strength Configuration
# ------------------------------------------------------------------------------
set_property SLEW SLOW [get_ports pad_sclk]
set_property DRIVE 8   [get_ports pad_sclk]
set_property SLEW SLOW [get_ports pad_mosi]
set_property DRIVE 8   [get_ports pad_mosi]
set_property SLEW SLOW [get_ports {pad_cs_n[*]}]
set_property DRIVE 8   [get_ports {pad_cs_n[*]}]
