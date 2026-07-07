# Architecture & design decisions

## Overview

`rv32e-design` is a **RV32E** (embedded, 16-register) machine-mode RISC-V core
in a small **Harvard** SoC, sized to fit comfortably on an iCE40HX4K with
headroom to spare. The whole system is plain Verilog-2005, synthesises with the
open toolchain (yosys + nextpnr + icestorm), and is verified in simulation with
cocotb/pyuvm.

```
                         iCE40HX4K  (top.v)
  clk 50 MHz ─► SB_PLL40_CORE ─► clk_core 40 MHz ─► reset counter ─► rst_n
                                        │
        ┌───────────────────────────────┴───────────────────────────────┐
        │                          rv32e_core                            │
        │   IF  ─────►  ID / EX  ─────►  MEM / WB                        │
        │   pc, imem   decode+regfile   dmem access, load align,         │
        │   fetch      +ALU+branch+CSR  writeback, CSR/trap commit       │
        └───────┬───────────────────────────────┬───────────────────────┘
      imem_addr │ imem_rdata          dmem_addr, │ dmem_rdata
                ▼                     wdata, we   ▼
        ┌──────────────┐        ┌───────────── data bus decode ─────────────┐
        │  imem_rom    │        │ drom (imem_rom)  0x1000-0x17FF  R/O init   │
        │  IMEM 4 KB   │        │ dram (bram_dp)   0x1800-0x1EFF  R/W RAM    │
        │  (seeded)    │        │ gpio   0x1F00 · uart 0x1F40 · mtimer 0x1F50│
        └──────────────┘        └───────────────────────────────────────────┘
                                     │ leds/buttons   │ uart_tx/rx   │ timer_irq
```

Sources: [top.v](../rtl/top.v), [rv32e_core.v](../rtl/rv32e_core.v).

- **ISA**: RV32E + `Zicsr`, machine mode only. 16 GP registers (x0–x15).
- **Pipeline**: 3 stages — `IF | ID/EX | MEM/WB`.
- **Clocking**: 50 MHz board oscillator → PLL → 40 MHz core; `rst_n` is released
  once a reset counter's MSB sets after the PLL locks.
- **Peripherals**: 8-bit GPIO, 8N1 UART, CLINT-style machine timer.

## The pipeline

Three stages, one instruction retired per cycle in the common case:

| Stage | Work done | Key signals |
|-------|-----------|-------------|
| **IF** | Present `pc` to the synchronous IMEM; the instruction arrives next cycle into `if_id_instr`. `fetch_pc`/`if_id_pc` track the address one cycle behind so PC-relative math is correct. | `pc`, `fetch_pc`, `if_id_*` |
| **ID/EX** | Decode, read the register file, forward, run the ALU, evaluate the branch condition, and compute CSR read/new values — all combinationally in one cycle. | `decoder`, `alu`, `branch_unit`, forwarding muxes |
| **MEM/WB** | The registered DMEM/peripheral output is valid here; align/extend loads, mux the write-back value, and commit CSR/trap state. | `ex_mem_*`, `load_data`, CSR commit |

Because both the IMEM and the register file are **synchronous-read BRAMs**, the
addresses they need must be presented one cycle early. That single fact drives
most of the pipeline's subtle logic (see the decisions below).

## Design decisions

### 1. RV32E instead of RV32I
16 registers instead of 32 halves the register file and shortens every
`rs1`/`rs2`/`rd` field to 4 bits, trimming decode and forwarding logic. On a
part with only 32 BRAMs and 7680 logic cells this headroom matters. The cost —
fewer registers for the compiler — is acceptable for small firmware, and GCC's
`ilp32e`/`-march=rv32e` multilib handles it. Hardware mul/div is not
implemented; `libgcc` supplies software routines.

### 2. Three-stage pipeline, branches resolved in ID/EX
A 3-stage pipeline is the sweet spot for BRAM-based fetch: deep enough to hide
the 1-cycle memory latency, shallow enough to keep hazard logic tiny. Branches,
jumps, traps and `mret` are all resolved in **ID/EX**, so a taken redirect
flushes the instructions already in flight rather than mispredicting far ahead.

Redirects insert **two** NOP bubbles, not one: `take_control_flow` injects the
first bubble, and `flush_pending` injects a second the following cycle to
discard the stale `imem_rdata` that the 1-cycle IMEM already latched for the
fall-through path. Straight-line code and not-taken branches run at 1 IPC.
See [rv32e_core.v](../rtl/rv32e_core.v) (`flush_pending`, `pc_next`).

### 3. Synchronous-read register file (inferred BRAM) with a WB bypass
The register file uses a **synchronous** read so yosys infers `SB_RAM40_4K`
instead of burning LUTs on a distributed-RAM/flop array. The timing contract
("Option-B"): `rs1`/`rs2` are presented during **IF** (extracted directly from
the incoming `imem_rdata`), so `rdata1/2` are valid in ID/EX. Because a BRAM
read port returns the *old* value when a write hits the same address in the same
cycle, two **bypass registers** capture the MEM/WB write and override the stale
read. See [regfile.v](../rtl/regfile.v).

### 4. Full forwarding + a single load-use stall
ALU results are forwarded from both **EX/MEM** and **MEM/WB** back into ID/EX,
so back-to-back ALU dependencies never stall. The one unavoidable bubble is the
**load-use hazard**: a load's data is not available until MEM/WB, so if the very
next instruction consumes it, `stall` freezes the PC, backs the IMEM address up
by one word to re-fetch, and re-presents the frozen `rs1/rs2` to the register
file. See `load_use_hazard` / `stall` in [rv32e_core.v](../rtl/rv32e_core.v).

### 5. Interrupts only fire on a real instruction (`if_id_valid`)
Traps are gated by `if_id_valid`, which is 0 while ID/EX holds a flush bubble.
Without this gate an interrupt taken on a bubble would latch `mepc = if_id_pc =
0`, and `mret` would return to address 0 and restart the program. This was a
real bug: a C `for(;;)` compiles to `j .`, which keeps the pipeline full of
bubbles, so a timer interrupt hit the window almost every time. The
`if_id_valid` gate guarantees `mepc` is always a valid instruction PC.
See `take_trap` and the trap-commit block in [rv32e_core.v](../rtl/rv32e_core.v).

### 6. Harvard split, and *why the data side is split again* (DROM + DRAM)
Loads cannot read IMEM (the data path ignores address bit 12), so all constants
and variables must live on the data bus. But the data RAM must be
**byte-writable** for `SB`/`SH`, and yosys maps a byte-enabled RAM onto
asymmetric BRAM tiles that **`icebram` cannot patch**. To keep fast reflashing
for initialised data, the 4 KB data window is split:

- **DROM** `0x1000–0x17FF` — a read-only init ROM built from the *same*
  single-port `imem_rom` primitive as IMEM, so it is icebram-patchable. Holds
  `.rodata` and the load image of `.data`.
- **DRAM** `0x1800–0x1EFF` — a plain byte-writable `bram_dp`, zero-initialised,
  never patched. Holds runtime `.data`, `.bss` and the stack.

`crt0` copies `.data` from DROM to DRAM and zeroes `.bss` at boot. See
[firmware-workflow.md](firmware-workflow.md) and [top.v](../rtl/top.v).

### 7. The icebram reflash trick
`imem_rom` is deliberately a **single-port ROM with no write port** so yosys maps
it to `SB_RAM40_4K` with matching read/write modes, which lets `ICE40_BRAMINIT`
propagate the `$readmemh` init into `INIT_0..F`. Both IMEM and DROM are seeded
with a **reproducible random pattern** (different PRNG seeds, different depths)
so `icebram` can locate their tiles unambiguously — random content also stops
yosys from constant-folding through the memories. `make fw` then swaps the seed
for the real program in the already-routed bitstream in ~3 s. See the `fw`
target in the [Makefile](../Makefile).

### 8. CSRs and the interrupt model
A minimal machine-mode CSR block: `mstatus`, `mie`, `mip` (read-only, composed
from the synchronised IRQ inputs), `mtvec`, `mepc`, `mcause`, and a 64-bit
`mcycle`/`mcycleh`. All six CSR access forms are decoded (`csrrw/s/c` + the
immediate variants) with correct "don't-write on x0/zero-source" semantics.

Two machine interrupt sources, each gated by its `mie` bit **and** the global
`mstatus.MIE`, with RISC-V priority (external before timer):

| Source | `mcause` | `mie` bit |
|--------|----------|-----------|
| Machine external (MEI) | `0x8000000B` (11) | 11 (MEIE) |
| Machine timer (MTI) | `0x80000007` (7) | 7 (MTIE) |
| `ecall` / `ebreak` | 11 / 3 (synchronous) | — |

On a trap the core clears `mstatus.MIE` and latches `mepc`/`mcause`; `mret`
re-sets `mstatus.MIE`. This is intentionally simplified — there is **no
MPIE/MPP stacking** — which is fine for a single privilege level with
non-nested handlers.

### 9. CLINT-style machine timer
[mtimer.v](../rtl/mtimer.v) exposes a free-running 64-bit `mtime` (one tick per
`clk_core`) and a 64-bit `mtimecmp`, memory-mapped at `0x1F50`. `timer_irq`
(MTIP) is asserted while `mtime ≥ mtimecmp`; firmware re-arms by writing a larger
`mtimecmp`. Re-arming relative to the previous deadline (`mtimecmp += INTERVAL`)
gives an **exact, drift-free** periodic grid regardless of interrupt-entry
latency — verified by the top-level `timer_blink` test (periods `50000×5`,
cumulative drift 0).

### 10. Registered peripheral bus
Every data source — DROM, DRAM, GPIO, UART, mtimer — has a **1-cycle registered
read**, matching the BRAM latency the core's MEM/WB stage expects. The select
lines are registered one cycle (`*_sel_r`) so the read mux lines up with the
registered `rdata`. Address decode is a flat compare on `dmem_addr` bits (see
the decode comment block in [top.v](../rtl/top.v)).

### 11. Clocking, reset, and a synthesis knob
The PLL turns the 50 MHz oscillator into 40 MHz (`DIVR=4, DIVF=63, DIVQ=4`). A
12-bit counter holds `rst_n` low until its MSB sets (2048 cycles, ~51 µs) after
`LOCK`, and any PLL glitch async-clears it. For simulation the PLL (which has no behavioural model) is
bypassed with `-DSIM_NO_PLL`. Synthesis uses `-dffe_min_ce_use 40`: it stops
yosys turning the 32-bit CSR write-enables into clock-enable pins, which
nextpnr would otherwise promote onto the scarce global network — freeing 3
global buffers. See the [Makefile](../Makefile) `YOSYS_FLAGS`.

## Current state — what works

Verified on this tree (see [README.md](README.md) for the raw numbers):

- **Full RV32E integer ISA**: ADD/SUB and immediates, all shifts, SLT/SLTU,
  logic ops, LUI/AUIPC, all branches, JAL/JALR, and every load/store width with
  byte-enable writes — 12/12 in the ISA suite.
- **CSRs + interrupts**: external IRQ, machine timer (MTIP), `ecall`/`ebreak`,
  `mret`, with correct `mepc`/`mcause`; drift-free periodic timer.
- **Peripherals end-to-end on `top.v`**: UART TX (`Hello from RV32E!`), GPIO
  LEDs, and the timer, running a real C application through the DROM/DRAM split.
- **Toolflow**: full bitstream via yosys/nextpnr/icepack, and ~3 s firmware
  reflash via icebram, both wired into the Makefile.
- **Timing**: closes at 40 MHz with margin (41.10 MHz achieved).

## Known limitations / not implemented

These are deliberate scope cuts, not bugs — listed so nobody is surprised:

- **No misaligned-access or fault traps**, and no `mtval`. Loads/stores assume
  aligned addresses; unaligned accesses are not detected.
- **Simplified `mstatus`**: only the global `MIE` bit is modelled (no
  MPIE/MPP stack), so nested interrupts are not supported.
- **External IRQ pin is tied off** in `top.v` (`irq = 0`); on hardware the timer
  is the only live interrupt source. The core fully supports an external IRQ —
  it is exercised in the `irq` ISA test — it is just not wired to a pad yet.
- **`FENCE` decodes to a NOP** (single-hart, in-order, no caches — nothing to
  order).
- **No hardware multiply/divide** (RV32E base only; `libgcc` provides software).
- **`tohost` is a simulation convention**: the store to `0x1FFC` is dropped by
  the hardware address decode (it lands in the peripheral window with no
  target), so it is harmless on the board and only meaningful to the testbench.
