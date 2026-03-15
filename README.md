## RV32‑TinySoC

Custom 32‑bit RV32I RISC‑V microcontroller SoC, built from the ground up and targeted for open‑source ASIC implementation on SkyWater SKY130 via the OpenLane flow.

---

### 1. Architecture Overview

RV32‑TinySoC is a small but complete System‑on‑Chip designed around a minimal RV32I core and a simple memory‑mapped peripheral subsystem.

- **RV32I Core (`riscv_core.v`)**
  - 32‑bit, 3‑stage pipeline (Fetch → Decode/Execute → Writeback).
  - Implements the base RV32I instruction set (LUI, AUIPC, JAL/JALR, branches, loads/stores, ALU ops).
  - Single unified memory interface shared for instruction fetch and data access.

- **APB‑Style Interconnect (`apb_interconnect.v`)**
  - Bridges the core’s memory interface to simple APB‑like slaves.
  - Performs address decoding and PRDATA multiplexing.
  - Exposes a single master port to:
    - 16 KB on‑chip RAM (`apb_slave_ram.v` + `ram_16k.v`).
    - UART controller (`apb_slave_uart.v` + `uart_mmio_wrapper.v` + `uart_top.v`).
    - 8‑bit GPIO (`apb_slave_gpio.v`).
    - Trap / test‑exit slave (`apb_slave_trap.v`) at `0x4000_F000` for simulation control.

- **UART Subsystem**
  - **`uart_tx.v` / `uart_rx.v`**: classic 8‑N‑1 transmitter and receiver.
  - **`uart_top.v`**: integrates TX/RX into a single block.
  - **`uart_mmio_wrapper.v`**: presents the UART as simple memory‑mapped registers:
    - `0x4000_0000`: write → TX data, read → TX busy status.
    - `0x4000_0004`: read → last received byte.

- **On‑Chip SRAM**
  - **16 KB dual‑port RAM** (`ram_16k.v`) mapped from `0x0000_0000` to `0x0000_3FFF`.
  - Port A is used as unified instruction/data memory via `apb_slave_ram.v`.

The top‑level integration is in **`mcu_top.v`**, which instantiates the core, APB interconnect, RAM, UART, GPIO, and trap logic.

---

### 2. Physical Design Target (Sky130 + OpenLane)

This RTL is being developed and iteratively tuned with **ASIC implementation in mind**:

- **Technology**: SkyWater **SKY130A** open PDK.
- **Flow**: OpenLane (as packaged in the IIC‑OSIC‑TOOLS container).
- **Top Module for Synthesis**: `mcu_top`.
- **Clocking**:
  - Single clock input `clk`.
  - Target frequency: **100 MHz** (`CLOCK_PERIOD = 10.0 ns` in `config.json`).
- **Design Configuration**:
  - `config.json` is set up for SKY130, with all essential RTL listed in `VERILOG_FILES`.
  - `layout/` and `gds/` are kept in the tree (with `.gitkeep`) as staging areas for OpenLane runs and final GDS artefacts.

The medium‑term goal is a **full tape‑out‑ready digital block** for a multi‑project wafer shuttle, demonstrating a complete open‑source MCU from RTL through GDS.

---

### 3. Firmware and Test Infrastructure

The SoC is validated using a simple bare‑metal firmware stack under `sw/`:

- **`sw/boot.s`**
  - Entry point at reset vector `0x0000_0000`.
  - Explicitly clears registers `x1..x31` in software (the hardware register file is intentionally un‑reset to save area).
  - Initializes the stack pointer (`sp = x2`) to the top of the 16 KB RAM at `0x0000_4000`.
  - Calls `main()` and, when `main` returns, writes `0x01` to `0x4000_F000` (trap slave) to signal the testbench, then loops forever.

- **`sw/main.c`**
  - Minimal C program that memory‑maps the UART at `0x4000_0000`.
  - Sends a short `"Hello\n"` string to verify the **core → APB → UART → pins** datapath.
  - Returns `0`, allowing the boot code to trigger the trap write.

- **`sw/link.ld`**
  - Simple linker script placing `.text`, `.data` and `.bss` into the 16 KB RAM region starting at `0x0000_0000`.
  - Designed for a bare‑metal RV32I toolchain (`-march=rv32i -mabi=ilp32`).

For simulation, the firmware is converted to a hex file and loaded into the RAM model; the **system testbench** `tb/mcu_soc_tb.v`:

- Generates a 100 MHz clock and power‑on reset.
- Instantiates `mcu_top` as the DUT.
- Performs **UART loopback** (`uart_tx` connected back to `uart_rx`).
- Monitors APB writes to `0x4000_F000` (trap) to print `TEST PASSED` and terminate the run.

---

### 4. The Learning Journey (First GitHub Repo)

This repository represents **my first GitHub project**, and the path to RV32‑TinySoC has been a genuine learning curve:

- It started as a **simple UART transceiver** experiment—just trying to understand how bits get serialized and deserialized over a single wire.
- From there, I gradually moved into:
  - Basic **digital design** and understanding finite‑state machines.
  - Writing **synthesizable Verilog** that tools like Yosys and OpenLane actually accept.
  - Learning how to structure designs as **hierarchical modules** (`uart_tx`, `uart_rx`, `uart_top`, wrappers, interconnects).
- The real inflection point was deciding to build a **full RV32I microcontroller**:
  - Implementing a 3‑stage RISC‑V pipeline.
  - Adding instruction and data memory.
  - Designing a simple APB‑style interconnect and multiple peripherals (UART, GPIO, trap).
  - Integrating bare‑metal firmware, linker scripts, and testbenches to close the loop from **software to hardware and back**.

Nothing here is “production‑grade silicon” yet—but every commit reflects a concrete concept learned:

- How a CPU fetches, decodes, and executes RISC‑V instructions.
- How memory‑mapped I/O hangs off a bus fabric.
- How physical design constraints (clocking, reset strategy, area, power) push back on pure “toy” RTL.

If you’re also on your first serious hardware project, this repo is intentionally kept **transparent and approachable**—you can trace the evolution from UART to full MCU just by reading the code and commit history.

---

### 5. Project Status and Next Steps

Current status:

- ✅ RV32I core, APB interconnect, UART, GPIO, RAM, and trap logic integrated in `mcu_top`.
- ✅ System‑level testbench with loopback UART and firmware‑driven trap.
- ✅ OpenLane configuration (`config.json`) targeting SKY130 with a 100 MHz clock.

Planned work:

- Tighten timing and area budgets based on synthesis and P&R results.
- Add more peripherals (e.g., SPI, timers) behind the APB interconnect.
- Iterate on clock‑gating and reset strategy for better PPA.
- Prepare final sign‑off checks for a shuttle‑class tape‑out.

Contributions, code reviews, and suggestions are very welcome—especially from folks with experience in RISC‑V microarchitectures or open‑source ASIC flows.

---

### 6. Author

**Bhavesh Khandelwal**  
Physical Design Lead, VLSI/Chip Design Club  
Ramaiah Institute of Technology  

This project is my hands‑on journey from basic UARTs to a complete custom RV32I microcontroller SoC, with the goal of eventually seeing it fabricated on real silicon.