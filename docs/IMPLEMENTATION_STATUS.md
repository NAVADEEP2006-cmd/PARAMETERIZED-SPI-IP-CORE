# Implementation Status Tracker

This document provides a truthful, evidence-based status report for every subsystem, feature, and deliverable in the Parameterized SPI IP Core project.

---

## Allowed Status Definitions

| Status | Exact Definition |
|---|---|
| **Not Started** | Engineering specification or future feature only; no RTL design or implementation exists. |
| **In Progress** | Active design, modeling, or coding underway; incomplete deliverables. |
| **Implemented — Not Verified** | Synthesizable RTL exists in repository, but has not yet been subjected to automated testbench checks. |
| **Simulation Verified** | RTL compiles without lint errors and has passed self-checking automated simulation suites with documented assertions. |
| **FPGA Implemented** | Design has been successfully synthesized, placed, routed, and timing-closed in an FPGA vendor tool (e.g., AMD Vivado). |
| **Hardware Tested** | Design has been programmed onto physical silicon (e.g., PYNQ-Z2 FPGA board) and functionally validated using physical instruments or attached peripherals. |

---

## 1. Subsystem Implementation Matrix

| Subsystem / Component | RTL Source File | Status | Verification & Evidence Summary |
|---|---|:---:|---|
| **SPI Master FSM** | `rtl/master/spi_master_fsm.sv` | **Simulation Verified** | 5-state Moore engine verified in unit testbench `tb_spi_master_fsm.sv` and full integration loopback. |
| **SCLK Clock Generator** | `rtl/master/spi_clock_gen.sv` | **Simulation Verified** | Verified across all 4 SPI modes ($CPOL \in \{0, 1\}$) and divider configurations in `tb_spi_clock_gen.sv` and `spi_tb.sv`. |
| **Bit Counter** | `rtl/master/spi_bit_counter.sv` | **Simulation Verified** | Verified for 1-bit, 8-bit, 16-bit, and 32-bit frames with synchronous clear priority in `tb_spi_bit_counter.sv`. |
| **TX Shift Register** | `rtl/master/spi_tx_shift.sv` | **Simulation Verified** | Preload and shift mechanics verified for MSB-first and LSB-first modes in `tb_spi_shift_regs.sv`. |
| **RX Shift Register** | `rtl/master/spi_rx_shift.sv` | **Simulation Verified** | Shift and latch mechanics verified for single-bit and multi-bit frames in `tb_spi_shift_regs.sv`. |
| **Chip Select Controller** | `rtl/master/spi_cs_ctrl.sv` | **Simulation Verified** | Glitch-free registered 1-hot decoding verified across 4 slave targets in `tb_spi_cs_ctrl.sv` and Suite 12 of `spi_tb.sv`. |
| **Performance Counters** | `rtl/master/spi_perf_counters.sv` | **Simulation Verified** | Exact latency ($104$ cycles), SCLK cycles ($96$ cycles), and transaction counts verified in Suite 6 of `spi_tb.sv`. |
| **Core SPI Master** | `rtl/master/spi_master.sv` | **Simulation Verified** | Validated across 16 test suites covering all modes, data widths, error handling, and reset recovery. |
| **SPI Master Top** | `rtl/master/spi_master_top.sv` | **Simulation Verified** | Validated via top-level wrapper integration and simulation filelists. |
| **SPI Slave Core** | `rtl/slave/spi_slave.sv` | **Simulation Verified** | Synchronous oversampling and frame error detection validated in full-duplex loopback across all 4 modes. |
| **Slave Tri-State Top** | `rtl/slave/spi_slave_top.sv` | **Simulation Verified** | Tri-state buffer modeling verified in full simulation suite. |
| **Pad & Loopback Wrapper** | `rtl/common/spi_pad_wrapper.sv` | **Simulation Verified** | Loopback and external pad modes verified; serves as top module for integration testbench. |
| **Multi-Device Scheduler** | `rtl/scheduler/` | **Not Started** | Architectural specification established in `rtl/scheduler/README.md`. RTL design is in the planning phase. |

---

## 2. Feature & Protocol Verification Tracker

| Feature / Capability | Intended Specification | Actual Baseline Status | Notes / Limitations |
|---|---|:---:|---|
| **SPI Mode 0 ($CPOL=0, CPHA=0$)** | Full-duplex transfer | **Simulation Verified** | Passed Suite 2 ($8$-bit word, MSB-first). |
| **SPI Mode 1 ($CPOL=0, CPHA=1$)** | Full-duplex transfer | **Simulation Verified** | Passed Suite 3 ($8$-bit word, MSB-first). |
| **SPI Mode 2 ($CPOL=1, CPHA=0$)** | Full-duplex transfer | **Simulation Verified** | Passed Suite 4 ($8$-bit word, MSB-first). |
| **SPI Mode 3 ($CPOL=1, CPHA=1$)** | Full-duplex transfer | **Simulation Verified** | Passed Suite 5 ($8$-bit word, MSB-first). |
| **8-Bit Word Width** | Standard transfer size | **Simulation Verified** | Default parameter setting; verified across all modes. |
| **16-Bit Word Width** | Parameterized transfer | **Simulation Verified** | Passed Suite 9 ($DATA\_WIDTH=16$). |
| **32-Bit Word Width** | Parameterized transfer | **Simulation Verified** | Passed Suite 10 ($DATA\_WIDTH=32$). |
| **1-Bit Word Width** | Boundary corner case | **Simulation Verified** | Passed Suite 14 ($DATA\_WIDTH=1$). |
| **MSB-First Ordering** | Standard bit order | **Simulation Verified** | Verified as baseline default. |
| **LSB-First Ordering** | Parameterized bit order | **Simulation Verified** | Passed Suite 11 ($LSB\_FIRST=1$). |
| **Multi-Slave CS Bus** | 1-hot mutual exclusion | **Simulation Verified** | Passed Suite 12 ($NUM\_SLAVES=4$). |
| **Streaming Transfers** | Back-to-back zero penalty | **Simulation Verified** | Passed Suite 8 with continuous `start`. |
| **Mid-Transfer Reset** | Synchronous recovery | **Simulation Verified** | Passed Suite 13 (immediate idle return). |
| **Error Separation** | Distinct `error` / `select_error` | **Simulation Verified** | Passed Suite 7 (invalid slave vs busy rejection). |
| **Autonomous Scheduling** | Hardware multi-peripheral arbiter | **Not Started** | Planned extension; requires arbiter and queue RTL. |
| **Descriptor Queues** | Request FIFO for transactions | **Not Started** | Planned extension. |
| **Result FIFO** | Completion telemetry queue | **Not Started** | Planned extension. |
| **AXI4-Lite Bus Interface** | Register bridge for SoC bus | **Not Started** | Planned future wrapper. |

---

## 3. Hardware Integration Tracker (TUL PYNQ-Z2)

| Deliverable | Target Platform | Status | Evidence / Notes |
|---|---|:---:|---|
| **Core Timing Constraints** | `constraints/pynq_z2/pynq_z2_timing.xdc` | **Implemented — Not Verified** | 50.0 MHz core clock constraint defined for OOC synthesis budget. |
| **Board Pin Mapping** | `constraints/pynq_z2/pynq_z2_pins.xdc` | **Implemented — Not Verified** | Pmod B (Header JB) pins mapped and verified against PYNQ-Z2 Schematic v1.0. |
| **Out-of-Context Synthesis** | AMD Zynq-7020 (`xc7z020clg400-1`) | **In Progress** | Vivado batch script `run_vivado.tcl` updated for Zynq-7020; local tool execution pending. |
| **Board Bitstream Generation** | TUL PYNQ-Z2 | **Not Started** | Requires full Vivado implementation run. |
| **BMI160 IMU Interfacing** | Pmod B Header | **Not Started** | Proposed hardware integration target. |
| **25LC256 EEPROM Interfacing** | Pmod B Header | **Not Started** | Proposed hardware integration target. |
| **Physical Oscilloscope Probing** | Lab Instrumentation | **Not Started** | Pending physical hardware lab setup. |
