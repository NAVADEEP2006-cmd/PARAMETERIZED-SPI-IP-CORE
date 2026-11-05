# Hardware Integration Guide: TUL PYNQ-Z2 Target

## 1. Target Hardware Platform Overview

The physical hardware demonstration target for this IP core is the **TUL PYNQ-Z2** development board, based on the **AMD/Xilinx Zynq-7020 SoC** (`xc7z020clg400-1`).

```text
+-----------------------------------------------------------------------------------+
|                                 TUL PYNQ-Z2 BOARD                                 |
|                                                                                   |
|   +--------------------------+    +-------------------------------------------+   |
|   | Realtek RTL8211E-VL PHY  |    | AMD Zynq-7020 SoC (xc7z020clg400-1)       |   |
|   | Pin H16 (125 MHz PL clk) |--> |                                           |   |
|   +--------------------------+    |   +-----------------------------------+   |   |
|                                   |   | Board Top (spi_pynq_z2_top.sv)    |   |   |
|   +--------------------------+    |   | - 2-stage input synchronizers     |   |   |
|   | Pushbuttons BTN0, BTN1   |--> |   | - Edge detection & debouncers     |   |   |
|   | Slide Switches SW[1:0]   |--> |   | - Transaction demo pattern gen    |   |   |
|   +--------------------------+    |   | - Pulse stretchers for LEDs       |   |   |
|                                   |   |                                   |   |   |
|                                   |   |   +---------------------------+   |   |   |
|                                   |   |   | Parameterized SPI Master  |   |   |   |
|                                   |   |   | Core (spi_master_top.sv)  |   |   |   |
|                                   |   |   | CLOCK_DIVIDER = 15        |   |   |   |
|                                   |   |   +---------------------------+   |   |   |
|                                   |   +-----------------------------------+   |   |
|                                   |         | pad_sclk, pad_mosi,             |   |
|                                   |         | pad_miso, pad_cs_n[0..3]        |   |
|                                   +---------|---------------------------------+   |
|                                             |                                     |
|                                             v                                     |
|                               +-------------------------------+                   |
|                               | Pmod B Header JB (Bank 34)    |                   |
|                               | Pin 1: W14 (pad_cs_n[0])      |                   |
|                               | Pin 2: Y14 (pad_mosi)         |                   |
|                               | Pin 3: T11 (pad_miso, pullup) |                   |
|                               | Pin 4: T10 (pad_sclk)         |                   |
|                               | Pin 7: V16 (pad_cs_n[1])      |                   |
|                               | Pin 8: W16 (pad_cs_n[2])      |                   |
|                               | Pin 9: V12 (pad_cs_n[3])      |                   |
|                               +-------------------------------+                   |
|                                             |                                     |
|                                             v                                     |
|                               +-------------------------------+                   |
|                               | Proposed External Peripherals |                   |
|                               | - Slave 0: Bosch BMI160 IMU   |                   |
|                               | - Slave 1: Microchip 25LC256  |                   |
|                               +-------------------------------+                   |
+-----------------------------------------------------------------------------------+
```

---

## 2. Clock Architecture Analysis

### 2.1 PL Reference Clock Source (Pin H16)
- **Physical Source:** The 125.0 MHz single-ended clock supplied to PL package pin `H16` (Bank 35) is driven by the onboard **Realtek RTL8211E-VL Gigabit Ethernet PHY** (transceiver IC `U5`, pin 40 `CLK125`).
- **Operating Note:** Because this reference clock originates from the Ethernet PHY rather than a dedicated standalone crystal oscillator, its stability depends on the power and initialization state of the PHY. In bare-metal PL bitstream workflows without active Ethernet linking, users should observe that the PHY clock runs freely once power is applied, but proper PCB power stabilization must be observed.
- **Clock Management Reality:** **No MMCM or Clocking Wizard IP is instantiated in this RTL baseline.** The design does not rely on imaginary clock generators. Instead:
  1. **Board Demonstration Wrapper (`spi_pynq_z2_top.sv`):** Clocks the core synchronously at 125.0 MHz directly from `sysclk` (pin `H16`). With `CLOCK_DIVIDER = 15`, the resulting SPI serial clock is:
     $$f_{\text{SCLK}} = \frac{125\text{ MHz}}{2 \times 15} = 4.167\text{ MHz}$$
     This is well within the 5.0 MHz signal-integrity limit required for unshielded Pmod flying leads.
  2. **SoC Production Target (Zynq PS-to-PL):** In a production Zynq-7000 SoC design, clocking is typically sourced from the Processing System's programmable clock generator (`FCLK_CLK0` configured to 50 MHz) and bridged via AXI4-Lite.
  3. **Out-of-Context (OOC) IP Budget:** Standalone IP synthesis (`spi_master_top.sv`) uses `pynq_z2_timing.xdc` defining a 50.0 MHz synchronous clock budget (20.0 ns period).

---

## 3. Authoritative Board Pin & Bank Allocations

All pin mappings are verified against the authoritative **TUL PYNQ-Z2 Schematic (Rev C)** and AMD Zynq-7000 CLG400 package pinouts.

### 3.1 Bank 35 Allocations (System Clocks & User Controls, VCCO = 3.3V)

| Port Name | FPGA Pin | Board Component | Bank | I/O Standard | Description |
|---|:---:|:---:|:---:|:---:|---|
| `sysclk` | **H16** | Ethernet PHY CLK125 | 35 | `LVCMOS33` | 125.0 MHz PL reference clock |
| `reset_btn` | **D19** | Pushbutton BTN0 | 35 | `LVCMOS33` | Synchronous active-high reset |
| `start_btn` | **D20** | Pushbutton BTN1 | 35 | `LVCMOS33` | Manual transaction trigger pulse |
| `sw_slave_sel[0]` | **M20** | Slide Switch SW0 | 35 | `LVCMOS33` | Slave selection address bit 0 |
| `sw_slave_sel[1]` | **M19** | Slide Switch SW1 | 35 | `LVCMOS33` | Slave selection address bit 1 |

### 3.2 Bank 34 Allocations (Pmod B & Status LEDs, VCCO = 3.3V)

> [!IMPORTANT]
> Authoritative schematic verification confirms that **Pmod B (Header JB) and user LEDs LD[3:0] are located on Bank 34**, not Bank 13. All signals interface at 3.3V LVCMOS.

| Port Name | FPGA Pin | Connector Pin | Bank | I/O Standard | Drive / Slew | Description |
|---|:---:|:---:|:---:|:---:|:---:|---|
| `pad_cs_n[0]` | **W14** | Pmod B (JB) Pin 1 (JB1_P) | **34** | `LVCMOS33` | 8 mA / SLOW | Active-low Chip Select 0 (Slave 0) |
| `pad_mosi` | **Y14** | Pmod B (JB) Pin 2 (JB1_N) | **34** | `LVCMOS33` | 8 mA / SLOW | Master Out Slave In |
| `pad_miso` | **T11** | Pmod B (JB) Pin 3 (JB2_P) | **34** | `LVCMOS33` | PULLUP true | Master In Slave Out (Internal pullup) |
| `pad_sclk` | **T10** | Pmod B (JB) Pin 4 (JB2_N) | **34** | `LVCMOS33` | 8 mA / SLOW | SPI Serial Clock output |
| `pad_cs_n[1]` | **V16** | Pmod B (JB) Pin 7 (JB3_P) | **34** | `LVCMOS33` | 8 mA / SLOW | Active-low Chip Select 1 (Slave 1) |
| `pad_cs_n[2]` | **W16** | Pmod B (JB) Pin 8 (JB3_N) | **34** | `LVCMOS33` | 8 mA / SLOW | Active-low Chip Select 2 (Slave 2) |
| `pad_cs_n[3]` | **V12** | Pmod B (JB) Pin 9 (JB4_P) | **34** | `LVCMOS33` | 8 mA / SLOW | Active-low Chip Select 3 (Slave 3) |
| `(spare)` | **W13** | Pmod B (JB) Pin 10 (JB4_N) | **34** | `LVCMOS33` | N/A | Spare GPIO / optional interrupt input |
| `GND` | Ground | Pmod B Pins 5, 11 | N/A | Ground | N/A | Electrical ground reference |
| `VCC` | 3.3V Power | Pmod B Pins 6, 12 | N/A | 3.3V | N/A | 3.3V auxiliary power output |
| `led_busy` | **R14** | Onboard LED LD0 | **34** | `LVCMOS33` | 4 mA / SLOW | High during active transaction |
| `led_done` | **P14** | Onboard LED LD1 | **34** | `LVCMOS33` | 4 mA / SLOW | Pulse-stretched transfer complete indicator |
| `led_error` | **N16** | Onboard LED LD2 | **34** | `LVCMOS33` | 4 mA / SLOW | Pulse-stretched error / reject indicator |
| `led_active` | **M14** | Onboard LED LD3 | **34** | `LVCMOS33` | 4 mA / SLOW | Core active heartbeat |

---

## 4. Distinction: Reusable IP Core vs Board Demonstration Top

| Feature | Reusable IP Core (`spi_master_top.sv`) | Board Demonstration Top (`spi_pynq_z2_top.sv`) |
|---|---|---|
| **Role** | Pure digital IP core for SoC / FPGA integration | Board-specific wrapper for physical lab testing |
| **System Interface** | Parallel control & data buses (`start`, `tx_data`, `rx_data`) | Pushbuttons (`BTN0`, `BTN1`), switches (`SW[1:0]`), LEDs |
| **Clock Port** | `clk` (Synchronous core clock) | `sysclk` (125 MHz PL reference clock from H16) |
| **Target Constraints**| `constraints/pynq_z2/pynq_z2_timing.xdc` (OOC 50 MHz) | `constraints/pynq_z2/pynq_z2_pins.xdc` (125 MHz + I/O) |
| **Synthesis Mode** | `-mode out_of_context` | Full board implementation |

---

## 5. Candidate Peripherals & Proposed Wiring

### 5.1 Bosch BMI160 6-Axis Inertial Measurement Unit (IMU)
- **Protocol Requirements:** SPI Mode 0 or 3, max 10.0 MHz SCLK, 8-bit addressing.
- **Wiring on Pmod B (Slave 0):**
  - BMI160 `CSB` $\rightarrow$ Pmod B Pin 1 (`W14`, `pad_cs_n[0]`)
  - BMI160 `SDI` $\rightarrow$ Pmod B Pin 2 (`Y14`, `pad_mosi`)
  - BMI160 `SDO` $\rightarrow$ Pmod B Pin 3 (`T11`, `pad_miso`)
  - BMI160 `SCx` $\rightarrow$ Pmod B Pin 4 (`T10`, `pad_sclk`)
  - BMI160 `GND` $\rightarrow$ Pmod B Pin 5
  - BMI160 `VDD` $\rightarrow$ Pmod B Pin 6 (3.3V)

### 5.2 Microchip 25LC256 256K SPI EEPROM
- **Protocol Requirements:** SPI Mode 0 or 3, max 10.0 MHz SCLK at 3.3V, 8-bit opcode/data.
- **Wiring on Pmod B (Slave 1):**
  - 25LC256 `\CS` $\rightarrow$ Pmod B Pin 7 (`V16`, `pad_cs_n[1]`)
  - 25LC256 `SI`  $\rightarrow$ Pmod B Pin 2 (`Y14`, shared `pad_mosi`)
  - 25LC256 `SO`  $\rightarrow$ Pmod B Pin 3 (`T11`, shared `pad_miso`)
  - 25LC256 `SCK` $\rightarrow$ Pmod B Pin 4 (`T10`, shared `pad_sclk`)
  - 25LC256 `\WP` $\rightarrow$ Tied High (3.3V)
  - 25LC256 `\HOLD`$\rightarrow$ Tied High (3.3V)

---

## 6. Hardware Safety & Limitations

> [!CAUTION]
> 1. **Proposed Status:** Physical hardware integration has been modeled and constrained, but **physical laboratory oscilloscope and logic analyzer validation on bench hardware remains pending**.
> 2. **Signal Integrity:** Unshielded flying leads on Pmod headers exhibit parasitic capacitance and inductance. Serial clock rates above 5.0 MHz are not recommended without oscilloscope verification.
> 3. **Voltage Protection:** Pmod B connects directly to Bank 34 with $200\ \Omega$ series protection resistors. Never connect 5V logic directly to these pins; 3.3V LVCMOS is mandatory.
