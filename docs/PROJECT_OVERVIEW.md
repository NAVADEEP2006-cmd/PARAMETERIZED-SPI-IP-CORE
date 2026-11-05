# Project Overview

## 1. Project Background

The Serial Peripheral Interface (SPI) is a synchronous, full-duplex, four-wire serial communication protocol widely adopted in digital and embedded systems for short-distance chip-to-chip data exchange. Initially developed by Motorola, SPI has become a ubiquitous de facto industry standard connecting host microcontrollers, digital signal processors (DSPs), and Field Programmable Gate Arrays (FPGAs) to diverse peripherals including analog-to-digital converters (ADCs), digital-to-analog converters (DACs), flash memories, EEPROMs, inertial measurement units (IMUs), and display controllers.

Unlike standardized computer buses such as PCI Express or I2C, SPI possesses no formal standardization committee. Instead, variations in clock polarity (CPOL), clock phase (CPHA), transmission bit ordering (MSB-first vs. LSB-first), word widths (8, 16, 32 bits), and baud rate requirements require flexible, adaptable controller logic. In academic and professional FPGA design, standard off-the-shelf microcontroller peripherals or monolithic vendor-generated IP blocks often obscure internal protocol mechanics, impose heavy licensing or resource footprints, and lack portability across FPGA families or ASIC standard-cell libraries.

This project delivers a **Parameterized Synthesizable SystemVerilog SPI IP Core** engineered from the ground up for reusability, protocol conformance, robust multi-peripheral arbitration, and complete verification transparency.

---

## 2. Motivation

In modern FPGA and System-on-Chip (SoC) architectures, serial interfaces serve as the sensory and telemetry backbone. FPGA systems frequently interface with multiple external sensors and memory ICs on the same board. However, design teams routinely encounter recurring friction points:

1. **Vendor IP Lock-in:** Vendor-generated SPI IP cores (e.g., AMD/Xilinx AXI Quad SPI) are tightly coupled to specific bus architectures (AXI4/AXI4-Lite) and tool suites, creating unnecessary resource overhead when a lightweight, native SystemVerilog core is required.
2. **Fixed-Function Controller Inflexibility:** Many open-source SPI implementations are hardcoded to 8-bit transfers and SPI Mode 0 ($CPOL=0, CPHA=0$), requiring error-prone manual RTL alterations to support 16-bit or 32-bit sensors or alternate SPI modes.
3. **Clock-Domain Crossing (CDC) and Metastability Hazards:** Naive SPI implementations frequently use the external serial clock ($SCLK$) directly as an asynchronous clock to internal registers, introducing severe clock-tree routing violations and metastability risks in high-speed FPGA fabric.
4. **Multi-Peripheral Contention:** Coordinating transactions across multiple SPI peripherals with differing speed limits and timing requirements requires structured chip-select management and non-intrusive bus telemetry.

Developing a fully parameterized, synthesizable, and rigorously verified SPI IP core addresses these engineering challenges, providing an open, transparent baseline for digital design education and production-ready hardware integration.

---

## 3. Problem Statement

Standard microcontroller and basic digital SPI implementations present significant engineering limitations:
- **Rigid Frame Sizing:** Inability to handle dynamic or parameterized word widths ($\ge 1$ bit) without software bit-packing overhead.
- **Unverified Corner Cases:** Failure to guarantee glitch-free chip-select assertions, deterministic back-to-back transfer timing, and clean recovery upon synchronous reset during mid-transaction states.
- **Lack of Multi-Peripheral Autonomy:** When communicating with multiple SPI devices operating at distinct frequencies and modes, traditional host processors waste substantial processing cycles manually polling busy flags and driving GPIO chip-select lines.

The engineering challenge is to design, model, and verify a vendor-independent, fully synchronous SystemVerilog IP Core that supports configurable SPI modes (0–3), parameterized word lengths (8, 16, 32 bits), glitch-free multi-slave decoding, non-intrusive telemetry counters, and a clean pathway toward an autonomous multi-device transaction scheduler.

---

## 4. Project Objectives

The project is structured around the following concrete engineering objectives:

1. **Synthesizable Core RTL Design:**
   - Implement a modular SPI Master controller supporting SPI Modes 0, 1, 2, and 3.
   - Support parameterized data word widths ($W \in \{8, 16, 32\}$ bits, arbitrary $W \ge 1$).
   - Implement an integer-parameterized clock divider ($CLOCK\_DIVIDER = D$) producing $f_{sclk} = f_{clk} / (2D)$.
   - Support selectable bit order ($LSB\_FIRST \in \{0, 1\}$).
   - Provide an active-low, glitch-free registered multi-peripheral chip-select decoder ($NUM\_SLAVES \ge 1$).
   - Enforce a 100% synchronous, single-clock-domain architecture using active-high synchronous resets without inferred latches.

2. **Synchronous Slave IP & Pad Integration:**
   - Design a companion synchronous SPI Slave core utilizing multi-stage flip-flop synchronizers to oversample external SPI lines, eliminating gated or derived clock hazards.
   - Implement an SoC pad integration wrapper (`spi_pad_wrapper.sv`) supporting both external chip-pad interfacing and internal loopback self-testing with clean tri-state ($pad\_miso$) control.

3. **SystemVerilog Verification Suite:**
   - Construct modular unit testbenches validating sub-blocks (clock divider, bit counter, shift registers, chip-select controller, master FSM).
   - Develop a comprehensive self-checking integration testbench (`spi_tb.sv`) covering 16 verification suites with automated assertions across all 4 modes, multi-slave indexing, streaming back-to-back transactions, reset resilience, and corner cases.

4. **Hardware Target Readiness (TUL PYNQ-Z2):**
   - Target the AMD/Xilinx Zynq-7020 SoC (`xc7z020clg400-1`) hosted on the TUL PYNQ-Z2 evaluation platform.
   - Provide verified timing constraints for a 50.0 MHz synchronous core budget.
   - Formulate authoritative board pin mappings for Pmod B and Pmod A expansions based on official board schematics.

5. **Advanced Subsystem Exploration (Transaction Scheduler):**
   - Architectural exploration and formal specification of an autonomous Multi-Device Transaction Scheduler subsystem to arbitrate, queue, and dispatch transactions to diverse peripherals without continuous host polling.

---

## 5. Project Scope & Boundary Definition

To maintain rigorous technical integrity, the engineering boundary of this repository is strictly established:

### In Scope (Implemented & Maintained):
- Synthesizable SystemVerilog RTL for Master, Slave, Clock Generator, Shift Registers, CS Decoder, and Diagnostics.
- Parameterized execution across word width, clock division, SPI modes 0–3, LSB/MSB first, and multi-slave count.
- Self-checking unit and integration SystemVerilog testbenches.
- Simulation automation via cross-platform Python, PowerShell, Makefile, and Verilator/Icarus Verilog toolchains.
- AMD Vivado batch automation Tcl scripts for elaboration, synthesis, implementation, and XSim simulation.
- PYNQ-Z2 physical constraints and hardware integration documentation.

### Out of Scope / Planned Extensions (Clearly Separated):
- **Autonomous Multi-Device Scheduler RTL:** Specified in architectural documentation; RTL design in planning phase.
- **AXI4 / AXI4-Lite Slave Register Interface:** Future bus bridge wrapper; not present in core baseline.
- **Direct Memory Access (DMA) Engine:** Future subsystem; transactions currently driven via direct system-side handshakes.
- **UVM Verification Environment:** Directed self-checking SystemVerilog testbenches are utilized; UVM test suite is planned for future releases.
- **Physical Silicon Validation:** Lab testbench with physical oscilloscope captures and sensor boards is documented as proposed hardware validation.

---

## 6. Applications

The parameterized core is suited for a broad range of FPGA and ASIC applications:
- **Embedded Sensor Interfacing:** High-throughput streaming from multi-axis inertial measurement units (IMUs, e.g., Bosch BMI160, MPU-9250), barometers, and temperature sensors.
- **Non-Volatile Memory Storage:** High-reliability read/write cycles to serial SPI EEPROMs (e.g., Microchip 25LC256) and SPI NOR Flash memory.
- **Industrial Data Acquisition:** Interfacing multi-channel SPI ADCs and DACs requiring strict timing determinism and programmable clock division.
- **FPGA-to-Microcontroller Inter-Processor Links:** Lightweight bidirectional control and telemetry channels between soft-core/hard-core processors and custom FPGA acceleration logic.

---

## 7. Expected Engineering Outcome

Upon completing the baseline implementation and verification, this repository provides:
- A clean, modular, verified digital IP baseline ready for immediate integration into Vivado block designs or custom RTL SoCs.
- A deterministic, glitch-free serial communication engine complete with cycle-accurate telemetry.
- An authoritative, peer-reviewable technical documentation package allowing students, engineers, and researchers to verify, replicate, and extend the IP core.
