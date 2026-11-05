# ==============================================================================
# pynq_z2_pins.xdc - Physical Pin Constraints for TUL PYNQ-Z2 (Zynq-7020 CLG400)
#
# Target Board:       TUL PYNQ-Z2 (xc7z020clg400-1)
# Top-Level Target:   spi_pynq_z2_top
# Documentation Ref:  TUL PYNQ-Z2 Schematic Rev C / User Manual v1.0
#
# Hardware Integration Status: PROPOSED (Laboratory physical validation baseline)
#
# FPGA Bank Allocation Summary:
#   - Bank 35 (VCCO = 3.3V):
#       sysclk       -> H16 (125 MHz PL reference clock from Ethernet PHY U5)
#       reset_btn    -> D19 (Pushbutton BTN0 - active-high reset)
#       start_btn    -> D20 (Pushbutton BTN1 - initiate transaction)
#       sw_slave_sel -> M20 (SW0), M19 (SW1) (Slide switches for slave select)
#   - Bank 34 (VCCO = 3.3V):
#       Pmod B (JB Header) SPI Bus:
#         pad_cs_n[0]  -> W14 (Pin 1, JB1_P)
#         pad_mosi     -> Y14 (Pin 2, JB1_N)
#         pad_miso     -> T11 (Pin 3, JB2_P)
#         pad_sclk     -> T10 (Pin 4, JB2_N)
#         pad_cs_n[1]  -> V16 (Pin 7, JB3_P)
#         pad_cs_n[2]  -> W16 (Pin 8, JB3_N)
#         pad_cs_n[3]  -> V12 (Pin 9, JB4_P)
#       User Diagnostic LEDs:
#         led_busy     -> R14 (LD0 - Core Busy)
#         led_done     -> P14 (LD1 - Transfer Done)
#         led_error    -> N16 (LD2 - Core Error)
#         led_active   -> M14 (LD3 - Transfer Active)
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Primary Clock (125 MHz Ethernet PHY Output -> H16, Bank 35)
# ------------------------------------------------------------------------------
set_property PACKAGE_PIN H16 [get_ports sysclk]
set_property IOSTANDARD LVCMOS33 [get_ports sysclk]
create_clock -period 8.000 -name sysclk -waveform {0.000 4.000} [get_ports sysclk]

# ------------------------------------------------------------------------------
# 2. Pushbuttons & Configuration Switches (Bank 35)
# ------------------------------------------------------------------------------
# Pushbutton BTN0: Synchronous Active-High Reset
set_property PACKAGE_PIN D19 [get_ports reset_btn]
set_property IOSTANDARD LVCMOS33 [get_ports reset_btn]

# Pushbutton BTN1: Start Transaction Trigger
set_property PACKAGE_PIN D20 [get_ports start_btn]
set_property IOSTANDARD LVCMOS33 [get_ports start_btn]

# Slide Switch SW0: Slave Select Bit 0
set_property PACKAGE_PIN M20 [get_ports {sw_slave_sel[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw_slave_sel[0]}]

# Slide Switch SW1: Slave Select Bit 1
set_property PACKAGE_PIN M19 [get_ports {sw_slave_sel[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw_slave_sel[1]}]

# ------------------------------------------------------------------------------
# 3. Pmod B (Header JB) - Physical SPI Master Signals (Bank 34, LVCMOS33)
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

# Pin 7: Chip Select 1 (JB3_P)
set_property PACKAGE_PIN V16 [get_ports {pad_cs_n[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {pad_cs_n[1]}]

# Pin 8: Chip Select 2 (JB3_N)
set_property PACKAGE_PIN W16 [get_ports {pad_cs_n[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {pad_cs_n[2]}]

# Pin 9: Chip Select 3 (JB4_P)
set_property PACKAGE_PIN V12 [get_ports {pad_cs_n[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {pad_cs_n[3]}]

# ------------------------------------------------------------------------------
# 4. User Status LEDs (Bank 34, LVCMOS33)
# ------------------------------------------------------------------------------
# LD0: Core Busy
set_property PACKAGE_PIN R14 [get_ports led_busy]
set_property IOSTANDARD LVCMOS33 [get_ports led_busy]

# LD1: Transfer Complete (Done)
set_property PACKAGE_PIN P14 [get_ports led_done]
set_property IOSTANDARD LVCMOS33 [get_ports led_done]

# LD2: Transaction / Slave Error
set_property PACKAGE_PIN N16 [get_ports led_error]
set_property IOSTANDARD LVCMOS33 [get_ports led_error]

# LD3: Transfer Active Heartbeat
set_property PACKAGE_PIN M14 [get_ports led_active]
set_property IOSTANDARD LVCMOS33 [get_ports led_active]

# ------------------------------------------------------------------------------
# 5. Slew Rate and Drive Strength Configuration (Pmod B & LEDs)
# ------------------------------------------------------------------------------
set_property SLEW SLOW [get_ports pad_sclk]
set_property DRIVE 8   [get_ports pad_sclk]
set_property SLEW SLOW [get_ports pad_mosi]
set_property DRIVE 8   [get_ports pad_mosi]
set_property SLEW SLOW [get_ports {pad_cs_n[*]}]
set_property DRIVE 8   [get_ports {pad_cs_n[*]}]

set_property SLEW SLOW [get_ports led_busy]
set_property DRIVE 4   [get_ports led_busy]
set_property SLEW SLOW [get_ports led_done]
set_property DRIVE 4   [get_ports led_done]
set_property SLEW SLOW [get_ports led_error]
set_property DRIVE 4   [get_ports led_error]
set_property SLEW SLOW [get_ports led_active]
set_property DRIVE 4   [get_ports led_active]
