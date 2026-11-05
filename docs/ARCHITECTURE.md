# System Architecture Specification

## 1. System Block Diagram

The Parameterized SPI IP Core comprises a modular hierarchy partitioned into synthesizable sub-blocks. The design enforces single-clock-domain synchronous operation throughout the core fabric.

```mermaid
flowchart TD
    subgraph Host_Side ["Host System Interface"]
        H_START["start"]
        H_TX["tx_data[W-1:0]"]
        H_SEL["slave_select[K-1:0]"]
        H_RX["rx_data[W-1:0]"]
        H_BUSY["busy"]
        H_DONE["done"]
        H_ERR["error / select_error"]
    end

    subgraph SPI_Master_Core ["spi_master.sv"]
        FSM["spi_master_fsm\n(5-State Moore Engine)"]
        CLKGEN["spi_clock_gen\n(SCLK Divider & Edge Strobes)"]
        TXSHIFT["spi_tx_shift\n(Registered Serializer)"]
        RXSHIFT["spi_rx_shift\n(Deserializer Register)"]
        BITCNT["spi_bit_counter\n(Word Bit Tracker)"]
        CSCTRL["spi_cs_ctrl\n(Active-Low CS Decoder)"]
        MISOSYNC["miso_sr\n(MISO Synchronizer FF Chain)"]
    end

    subgraph Physical_SPI ["Physical SPI Bus Pins"]
        P_SCLK["sclk (Output)"]
        P_MOSI["mosi (Output)"]
        P_MISO["miso (Input)"]
        P_CS["cs_n[NUM_SLAVES-1:0] (Output)"]
    end

    H_START -->|start_req| FSM
    H_TX -->|load_data| TXSHIFT
    H_SEL -->|slave_select| CSCTRL

    FSM -->|run, sclk_en| CLKGEN
    FSM -->|cs_active| CSCTRL
    FSM -->|accept| TXSHIFT
    FSM -->|tx_clear| TXSHIFT
    FSM -->|capture| RXSHIFT
    FSM --> H_BUSY
    FSM --> H_DONE

    CLKGEN -->|tick, lead_edge, trail_edge| FSM
    CLKGEN -->|shift_evt| TXSHIFT
    CLKGEN -->|sample_evt| RXSHIFT
    CLKGEN -->|inc| BITCNT
    BITCNT -->|bit_last| FSM

    CLKGEN --> P_SCLK
    TXSHIFT --> P_MOSI
    P_MISO --> MISOSYNC
    MISOSYNC -->|miso_s| RXSHIFT
    RXSHIFT -->|rx_data_r| H_RX
    CSCTRL --> P_CS
```

---

## 2. SPI Communication Protocol & Operating Modes

SPI is a synchronous, four-wire protocol operating in full duplex:
- **`SCLK` (Serial Clock):** Generated exclusively by the SPI Master to synchronize data transfer.
- **`MOSI` (Master Out Slave In):** Serial data transmitted from Master to Slave.
- **`MISO` (Master In Slave Out):** Serial data transmitted from Slave to Master.
- **`CS_n` (Chip Select, Active-Low):** Dedicated line asserted low to select an individual peripheral.

### SPI Operating Modes

The relationship between clock polarity and sampling phase is governed by two parameters:
- **`CPOL` (Clock Polarity):** Defines the idle level of `sclk` when no transaction is active.
- **`CPHA` (Clock Phase):** Defines whether data is sampled on the leading (first) or trailing (second) clock edge of each bit cycle.

$$\text{SPI\_MODE} = \{\text{CPOL}, \text{CPHA}\}$$

| Mode | CPOL | CPHA | SCLK Idle State | Leading SCLK Edge | Trailing SCLK Edge | Data Sample Edge | Data Shift Edge |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **0** | 0 | 0 | Low (`1'b0`) | Rising | Falling | Leading (Rising) | Trailing (Falling) |
| **1** | 0 | 1 | Low (`1'b0`) | Rising | Falling | Trailing (Falling) | Leading (Rising) |
| **2** | 1 | 0 | High (`1'b1`) | Falling | Rising | Leading (Falling) | Trailing (Rising) |
| **3** | 1 | 1 | High (`1'b1`) | Falling | Rising | Trailing (Rising) | Leading (Falling) |

### Mode 0 & Mode 1 vs. Preload Mechanics
- In **`CPHA = 0`** (Modes 0 & 2), the first data bit must be valid on `mosi` *before* the first clock edge. The TX shift register therefore preloads the MSB/LSB directly onto the output flip-flop upon transaction load.
- In **`CPHA = 1`** (Modes 1 & 3), `mosi` transitions on the leading edge and is sampled on the trailing edge. The output flip-flop is held at idle until the leading edge occurs.

---

## 3. SPI Master Subsystem Architecture

The SPI Master (`rtl/master/spi_master.sv`) coordinates transaction lifecycle execution through coordinated sub-blocks:

```mermaid
stateDiagram-v2
    [*] --> S_IDLE
    S_IDLE --> S_SELECT: start && sel_valid (accept=1)
    S_SELECT --> S_TRANSFER: Next Clock Edge
    S_TRANSFER --> S_DESELECT: trail_edge && bit_last (xfer_last)
    S_DESELECT --> S_DONE: tick (capture=1)
    S_DONE --> S_IDLE: Next Clock Edge (cs_n deasserts)
```

### A. Finite-State Machine (`spi_master_fsm.sv`)
The transaction controller is a deterministic 5-state Moore engine:
1. **`S_IDLE`:** Core is quiescent (`busy=0, done=0, cs_active=0`). Evaluates incoming `start` and `slave_select`. If valid, asserts `accept` for one clock cycle and transitions to `S_SELECT`.
2. **`S_SELECT`:** Duration: exactly 1 cycle (`busy=1`). `cs_active` is asserted, causing the registered `cs_n` decoder output to fall low on the subsequent clock edge. Provides setup time before SCLK toggles.
3. **`S_TRANSFER`:** Duration: exactly $2 \times W \times D$ system clock cycles (`busy=1, run=1, sclk_en=1`). SCLK actively toggles $2W$ times. Leaves when the final bit trailing edge occurs (`xfer_last`).
4. **`S_DESELECT`:** Duration: exactly $D$ system clock cycles (`busy=1, run=1, sclk_en=0`). SCLK is held idle at `CPOL`. Provides guaranteed hold time after serial transmission. On the final tick, `capture` pulses to latch deserialized data into the holding register.
5. **`S_DONE`:** Duration: exactly 1 cycle. **`busy=0`**, **`done=1`**. `cs_active=0` causes `cs_n` to return high on the transition back to `S_IDLE`.

### B. Clock Divider & Edge Generator (`spi_clock_gen.sv`)
The clock generator produces the serial clock and single-cycle timing strobes:
- **Counter Range:** Modulo-$D$ counter counting from $0$ to $D-1$, where $D = \text{CLOCK\_DIVIDER}$.
- **Strobe Signals:**
  - `tick`: Pulses for 1 clock cycle every $D$ clock cycles while `run = 1`.
  - `lead_edge`: Pulses when SCLK departs from the idle polarity (`CPOL`).
  - `trail_edge`: Pulses when SCLK returns to the idle polarity (`CPOL`).
- **Synchronous Output Register:** SCLK is generated directly from an internal flip-flop toggling on `tick && sclk_en`, preventing combinational clock glitches.

### C. Shift Registers (`spi_tx_shift.sv`, `spi_rx_shift.sv`)
- **Transmit Register:** Features registered serial output (`serial_out`). Configured by `PRELOAD_MSB` to support CPHA phase requirements. Supports both MSB-first (left shift) and LSB-first (right shift) without datapath duplication.
- **Receive Register:** Shift register sampling synchronized MISO. Handles single-bit word configurations ($W=1$) safely via generate logic without synthesis warnings.

### D. Chip Select Controller (`spi_cs_ctrl.sv`)
- Decodes binary `slave_select` into an active-low 1-hot `cs_n` bus of width `NUM_SLAVES`.
- Registered output stage ensures glitch-free CS transitions.
- Latches `slave_select` on transaction start, preventing mid-transaction address corruption.

---

## 4. SPI Slave Subsystem Architecture

The SPI Slave (`rtl/slave/spi_slave.sv`) operates synchronously within its own local clock domain:

```mermaid
flowchart LR
    subgraph Slave_Inputs ["External SPI Inputs"]
        SCLK_IN["sclk"]
        MOSI_IN["mosi"]
        CS_IN["cs_n"]
    end

    subgraph Sync_Domain ["Local Clock Domain (clk)"]
        SYNC_FF["Multi-Stage Flip-Flop Synchronizers\n(SLAVE_SYNC_STAGES >= 2)"]
        EDGE_DET["Edge Detectors\n(cs_fall, cs_rise, lead_edge, trail_edge)"]
        SLV_FSM["Slave Shift & Bit Tracking"]
        SLV_OBUFT["MISO Tri-State Driver\n(spi_slave_top.sv)"]
    end

    subgraph Host_Slave_Out ["Host System Interface"]
        SLV_RX["rx_data[W-1:0]"]
        SLV_VLD["rx_valid"]
        SLV_ERR["frame_error"]
    end

    SCLK_IN --> SYNC_FF
    MOSI_IN --> SYNC_FF
    CS_IN --> SYNC_FF

    SYNC_FF --> EDGE_DET
    EDGE_DET --> SLV_FSM
    SLV_FSM --> SLV_RX
    SLV_FSM --> SLV_VLD
    SLV_FSM --> SLV_ERR
    SLV_FSM --> SLV_OBUFT
```

### Key Slave Architectural Principles:
1. **No Derived Clocks:** Incoming `sclk` is treated as asynchronous serial data, oversampled by the slave's local clock `clk`.
2. **Oversampling Requirement:** $f_{clk\_slave} \ge 4 \times f_{sclk}$. SCLK half-period must span at least 2 local clock cycles for deterministic edge capture.
3. **Loopback Minimum Divider:** For master-slave loopback through pad wrappers, round-trip synchronizer delay requires:
   $$\text{CLOCK\_DIVIDER} \ge \text{MISO\_SYNC\_STAGES} + 4$$
4. **Frame Integrity Check:** Asserts `frame_error` upon `cs_n` deassertion if early frame truncation ($0 < \text{bits} < W$) or clock overrun ($> W$) is detected.

---

## 5. Telemetry & Diagnostic Subsystem (`spi_perf_counters.sv`)

The core integrates non-intrusive 32-bit hardware performance counters enabled via `ENABLE_PERF = 1`:
- `perf_txn_count`: Total completed transactions (`done` pulses).
- `perf_bits_total`: Cumulative payload bits transferred ($N_{txn} \times W$).
- `perf_busy_cycles`: Cumulative clock cycles with `busy = 1`.
- `perf_total_cycles`: Free-running cycle timer since reset or `perf_clear`.
- `perf_last_latency`: Cycle latency of most recent transaction ($2WD + D + 2$).
- `perf_last_sclk_cycles`: SCLK active toggling duration of most recent transaction ($2WD$).
- `perf_reject_count`: Count of rejected start attempts (`error` pulses).

> [!NOTE]
> These counters provide hardware telemetry and cycle-accurate diagnostic observability. They do not enforce arbitration policies or quality-of-service guarantees.

---

## 6. Multi-Device Transaction Scheduler Subsystem (Planned Extension)

The project explores an autonomous multi-device scheduler to coordinate transactions across heterogeneous peripherals:

```mermaid
flowchart TD
    subgraph Proposed_Scheduler ["Planned Multi-Device Scheduler Subsystem"]
        REQ_QUEUE["Descriptor FIFO\n(Slave ID, Priority, TX Data)"]
        ARBITER["Multi-Peripheral Arbiter\n(Strict Priority / Round-Robin)"]
        TIMER["Periodic Poll Timers\n(Sensor Polling Engine)"]
        DISPATCH["Transaction Dispatcher\n(Drives start, tx_data, slave_select)"]
        RES_FIFO["Result FIFO\n(RX Data, Slave ID, Timestamp)"]
    end

    subgraph Baseline_Master ["Baseline SPI Master Core (spi_master.sv)"]
        CORE_MST["Core SPI Master Engine"]
    end

    REQ_QUEUE --> ARBITER
    TIMER --> ARBITER
    ARBITER --> DISPATCH
    DISPATCH --> CORE_MST
    CORE_MST -->|done, rx_data| RES_FIFO
```

> [!IMPORTANT]
> The Multi-Device Transaction Scheduler is currently in the architectural specification phase. The synthesizable RTL arbiter and descriptor queues are planned extensions and are not included in the baseline RTL.
>
> **Compile-Time vs. Runtime Configuration Distinction:**
> In the current synthesizable baseline core (`spi_master.sv`), protocol parameters (`SPI_MODE`, `CLOCK_DIVIDER`, `DATA_WIDTH`, and `LSB_FIRST`) are compile-time Verilog parameters uniform across all transactions. In contrast, the planned Multi-Device Scheduler subsystem is specified to introduce dynamic per-device transaction descriptors, enabling runtime reconfiguration of clock rate, SPI mode, and word length tailored to individual attached peripherals.


---

## 7. Board Demonstration Top & Integration Wrappers

```mermaid
flowchart TD
    subgraph PYNQ_Z2_Top ["Physical Board Wrapper: spi_pynq_z2_top.sv"]
        CLK_IN["sysclk (125 MHz from Realtek RTL8211E-VL PHY U5 pin 46 -> H16, Bank 35)"]
        BTN_IN["reset_btn (D19), start_btn (D20)"]
        SW_IN["sw_slave_sel[1:0] (M20, M19)"]
        SYNC["2-Stage Synchronizers, Start Debouncer & Edge Detector"]
        DEMO_GEN["Demo Pattern Generator (tx_data += 1)"]
        PULSE_EXT["LED Pulse Stretchers"]
        LED_OUT["LEDs: busy (LD0), done (LD1) [Bank 34]\nerror (LD2), active (LD3) [Bank 35]"]
    end

    subgraph Core_Top ["Reusable IP: spi_master_top.sv"]
        CORE["SPI Master Engine (CLOCK_DIVIDER=15 -> 4.167 MHz SCLK)"]
    end

    subgraph Pmod_B ["Pmod B Header JB (Bank 34)"]
        PAD_SPI["pad_sclk, pad_mosi, pad_miso, pad_cs_n[0..3]"]
    end

    CLK_IN --> SYNC
    BTN_IN --> SYNC
    SW_IN --> SYNC
    SYNC --> DEMO_GEN
    DEMO_GEN -->|start, tx_data, slave_select| CORE
    CLK_IN --> CORE
    CORE -->|busy, done, error, transfer_active| PULSE_EXT
    PULSE_EXT --> LED_OUT
    CORE --> PAD_SPI
```

1. **`spi_pad_wrapper.sv` (Simulation & Loopback):** Provides pad-level modeling, bidirectional tri-state MISO emulation, and self-testing loopback interconnect between master and an internal slave.
2. **`spi_pynq_z2_top.sv` (Hardware Lab Demonstration):** Bridges physical PYNQ-Z2 board pins (125 MHz clock on H16 from Ethernet PHY U5 pin 46, debounced pushbuttons, switches, LEDs) to the reusable IP core without requiring an external AXI master or unconstrained bitstream synthesis. SCLK operates at 4.167 MHz ($125\text{ MHz} / (2 \times 15)$), serving as a conservative initial operating target pending physical measurement (< 5 MHz recommended for unshielded Pmod headers).
