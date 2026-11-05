# Multi-Device Transaction Scheduler Subsystem (Planned Extension)

> [!NOTE]
> **Subsystem Status: Planned / Under Specification**  
> RTL implementation of the multi-device scheduler is not yet implemented in this baseline. This document outlines the intended engineering specification and requirements for upcoming milestone releases.

---

## 1. Architectural Motivation

The core SPI master (`spi_master.sv`) provides robust single-transaction execution across `NUM_SLAVES` chip-select lines. However, modern embedded and FPGA systems frequently interface with heterogeneous SPI peripherals simultaneously (e.g., an IMU requiring periodic high-rate polling at 1 kHz alongside an EEPROM serviced asynchronously on host read/write requests).

Without hardware-assisted scheduling, the host processor must manually poll `busy`, manage timing deadlines, arbitrate bus contention, and assert chip selects. The **Multi-Device Transaction Scheduler** is planned as an autonomous upper-layer subsystem sitting between host logic and `spi_master`.

---

## 2. Planned Subsystem Architecture

```text
               +-------------------------------------------------------------+
               |        Planned Multi-Device SPI Scheduler Subsystem          |
               |                                                             |
Host Command   |   +-------------------+       +-------------------------+   |
Interface ---->|   | Command Queue /   | ----> | Round-Robin / Priority  |   |
(Write Req)    |   | Descriptors       |       | Arbiter Engine          |   |
               |   +-------------------+       +-------------------------+   |
               |                                            |                |
               |   +-------------------+                    v                |
Host Telemetry |   | Completed Result  | <---- [ Active Transaction Dispatch]|
Interface <----|   | FIFO / Status Reg |                    |                |
               |   +-------------------+                    |                |
               +--------------------------------------------|----------------+
                                                            |
                                                            v
                                            +-------------------------------+
                                            | Underlying SPI Master Core    |
                                            | (spi_master.sv)               |
                                            +-------------------------------+
```

---

## 3. Specification Requirements (Planned)

### A. Peripheral Target Profiles
- Configurable per-slave SPI modes (e.g., Slave 0 at Mode 0, Slave 1 at Mode 3).
- Configurable per-slave clock divider rates to match maximum SPI speeds of individual target ICs.
- Parameterized word lengths (8-bit, 16-bit, 32-bit transfers).

### B. Scheduling Policies Under Evaluation
1. **Strict Priority:** Fixed priority order for time-critical sensor streaming.
2. **Round-Robin Fair Scheduling:** Guarantees starvation-free access across all active slaves.
3. **Periodic Timer-Triggered Dispatch:** Hardware counter triggering periodic polling transactions.

### C. Interface Contract
- **Descriptor Queue:** Depth-parameterized request FIFO accepting target slave index, TX data, and priority tag.
- **Completion FIFO / Status:** Returns RX data, slave index, status flags (success, bus error), and cycle timestamp.

---

## 4. Verification & Implementation Roadmap

| Milestone | Objective | Deliverables | Status |
|---|---|---|---|
| **M1: Specification & Interface** | Finalize descriptor format and register map | Architecture & timing diagram | **Completed** |
| **M2: Arbiter RTL Design** | Implement Round-Robin & Priority arbitration core | Synthesizable SystemVerilog RTL | **Planned** |
| **M3: Queue & Dispatcher** | Implement descriptor FIFO and master bridge | Synthesizable SystemVerilog RTL | **Planned** |
| **M4: Simulation Verification** | Multi-device mixed traffic testbench | SystemVerilog self-checking TB | **Planned** |
| **M5: FPGA Validation** | Dual-peripheral hardware demo on PYNQ-Z2 | Vivado bitstream & hardware capture | **Planned** |
