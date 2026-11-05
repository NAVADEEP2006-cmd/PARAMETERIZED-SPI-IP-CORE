# Hardware Integration Guide: TUL PYNQ-Z2 Target

## 1. Target Hardware Platform Overview

The primary hardware target for this IP core is the **TUL PYNQ-Z2** development board, centered on the **AMD/Xilinx Zynq-7020 SoC** (`xc7z020clg400-1`).

```text
+-----------------------------------------------------------------------------------+
|                                 TUL PYNQ-Z2 BOARD                                 |
|                                                                                   |
|   +--------------------+          +-------------------------------------------+   |
|   | 125 MHz Oscillator | -------> | AMD Zynq-7020 SoC (xc7z020clg400-1)       |   |
|   | Pin H16 (sysclk)   |          |                                           |   |
|   +--------------------+          |   +-------------------+                   |   |
|                                   |   | Clocking Wizard / |                   |   |
|   +--------------------+          |   | MMCM (125->50MHz) |                   |   |
|   | BTN0 Pushbutton    | -------> |   +-------------------+                   |   |
|   | Pin D19 (reset)    |          |             |                             |   |
|   +--------------------+          |             v                             |   |
|                                   |   +-----------------------------------+   |   |
|                                   |   | Parameterized SPI Master Core     |   |   |
|                                   |   | (spi_master_top.sv)               |   |   |
|                                   |   +-----------------------------------+   |   |
|                                   |             | pad_sclk, pad_mosi,         |   |
|                                   |             | pad_miso, pad_cs_n[0..1]    |   |
|                                   +-------------|-----------------------------+   |
|                                                 |                                 |
|                                                 v                                 |
|                                   +---------------------------+                   |
|                                   | Pmod B Header (JB)        |                   |
|                                   | Pin 1: W14 (pad_cs_n[0])  |                   |
|                                   | Pin 2: Y14 (pad_mosi)     |                   |
|                                   | Pin 3: T11 (pad_miso)     |                   |
|                                   | Pin 4: T10 (pad_sclk)     |                   |
|                                   +---------------------------+                   |
|                                                 |                                 |
|                                                 v                                 |
|                                   +---------------------------+                   |
|                                   | Proposed Peripheral ICs   |                   |
|                                   | - Bosch BMI160 6-Axis IMU |                   |
|                                   | - Microchip 25LC256 EEPROM|                   |
|                                   +---------------------------+                   |
+-----------------------------------------------------------------------------------+
```

---

## 2. Authoritative Board Pin Allocations (Pmod B & System)

The physical pin mappings in `constraints/pynq_z2/pynq_z2_pins.xdc` are derived directly from the official **TUL PYNQ-Z2 Schematic (Rev C)** and user manual:

| Functional Port | FPGA Package Pin | Connector Pin | Bank | I/O Standard | Drive / Slew | Documentation Source |
|---|:---:|:---:|:---:|:---:|:---:|---|
| `sysclk` | **H16** | Onboard 125 MHz Osc | 35 | `LVCMOS33` | N/A (Input) | PYNQ-Z2 Schematic sheet 3 |
| `reset` | **D19** | Pushbutton BTN0 | 35 | `LVCMOS33` | N/A (Input) | PYNQ-Z2 Schematic sheet 4 |
| `pad_cs_n[0]` | **W14** | Pmod B (JB) Pin 1 | 13 | `LVCMOS33` | 8 mA / SLOW | PYNQ-Z2 Schematic sheet 6 (JB1_P) |
| `pad_mosi` | **Y14** | Pmod B (JB) Pin 2 | 13 | `LVCMOS33` | 8 mA / SLOW | PYNQ-Z2 Schematic sheet 6 (JB1_N) |
| `pad_miso` | **T11** | Pmod B (JB) Pin 3 | 13 | `LVCMOS33` | PULLUP True | PYNQ-Z2 Schematic sheet 6 (JB2_P) |
| `pad_sclk` | **T10** | Pmod B (JB) Pin 4 | 13 | `LVCMOS33` | 8 mA / SLOW | PYNQ-Z2 Schematic sheet 6 (JB2_N) |
| `pad_cs_n[1]` | **V16** | Pmod B (JB) Pin 7 | 13 | `LVCMOS33` | 8 mA / SLOW | PYNQ-Z2 Schematic sheet 6 (JB3_P) |
| `GND` | Ground | Pmod B Pins 5, 11 | N/A | Ground | N/A | Pmod standard ground reference |
| `VCC` | 3.3V Power | Pmod B Pins 6, 12 | N/A | 3.3V | N/A | Pmod standard power delivery |

> [!NOTE]
> Pmod B pins on the PYNQ-Z2 are connected directly to Zynq Bank 13 through $200\ \Omega$ series protection resistors. The `LVCMOS33` standard with 8 mA drive and slow slew rate is selected to mitigate ringing and overshoot on breadboards and flying-lead jumpers.

---

## 3. Candidate Peripherals & Proposed Wiring

### 3.1 Bosch BMI160 6-Axis Inertial Measurement Unit (IMU)
- **Primary Function:** 16-bit accelerometer and gyroscope for motion telemetry.
- **Protocol Requirements:**
  - SPI Mode: Mode 0 ($CPOL=0, CPHA=0$) or Mode 3 ($CPOL=1, CPHA=1$).
  - Max SPI SCLK: Up to 10.0 MHz.
  - Word Width: 8-bit command/register addressing, multi-byte burst reading.
- **Proposed Pmod B Wiring (Slave 0):**
  - BMI160 `CSB` $\rightarrow$ Pmod B Pin 1 (`W14`, `pad_cs_n[0]`)
  - BMI160 `SDI` $\rightarrow$ Pmod B Pin 2 (`Y14`, `pad_mosi`)
  - BMI160 `SDO` $\rightarrow$ Pmod B Pin 3 (`T11`, `pad_miso`)
  - BMI160 `SCx` $\rightarrow$ Pmod B Pin 4 (`T10`, `pad_sclk`)
  - BMI160 `GND` $\rightarrow$ Pmod B Pin 5
  - BMI160 `VDD` $\rightarrow$ Pmod B Pin 6 (3.3V)

### 3.2 Microchip 25LC256 256K SPI EEPROM
- **Primary Function:** Non-volatile memory storage (32,768 bytes organized as $32\text{K} \times 8$).
- **Protocol Requirements:**
  - SPI Mode: Mode 0 ($CPOL=0, CPHA=0$) or Mode 3 ($CPOL=1, CPHA=1$).
  - Max SPI SCLK: Up to 10.0 MHz at 3.3V ($CLOCK\_DIVIDER \ge 3$ from 50 MHz core clock).
  - Word Width: 8-bit opcode, 16-bit address, 8-bit data payload.
- **Proposed Pmod B Wiring (Slave 1):**
  - 25LC256 `\CS` $\rightarrow$ Pmod B Pin 7 (`V16`, `pad_cs_n[1]`)
  - 25LC256 `SI`  $\rightarrow$ Pmod B Pin 2 (`Y14`, shared `pad_mosi`)
  - 25LC256 `SO`  $\rightarrow$ Pmod B Pin 3 (`T11`, shared `pad_miso`)
  - 25LC256 `SCK` $\rightarrow$ Pmod B Pin 4 (`T10`, shared `pad_sclk`)
  - 25LC256 `\WP` $\rightarrow$ Tied High (3.3V)
  - 25LC256 `\HOLD`$\rightarrow$ Tied High (3.3V)

---

## 4. Hardware Safety & Current Limitations

> [!CAUTION]
> 1. **Proposed Status:** Physical hardware integration with the BMI160 and 25LC256 has **not yet been physically executed in the lab**. The pin mappings and electrical standards above are strictly engineering proposals based on verified board schematics.
> 2. **Signal Integrity:** When using breadboards or flying leads, keep SCLK frequencies under 5.0 MHz ($CLOCK\_DIVIDER \ge 5$) to prevent ground bounce and signal reflections on unshielded lines.
> 3. **Voltage Levels:** Verify that all connected external modules operate at 3.3V. Applying 5V directly to Pmod pins will cause permanent damage to the Zynq-7020 FPGA I/O banks.
