# Documentation

Design documentation for the **rv32e-design** SoC — a minimal RV32E soft-core
for the iCE40HX4K FPGA with an icebram fast-reflash firmware flow.

This folder records *why* the design is the way it is, *what* currently works
(with verified numbers), and *how* to simulate it and build/flash firmware.

## Contents

| Document | What it covers |
|----------|----------------|
| [architecture.md](architecture.md) | Block diagram, the 3-stage pipeline, every notable design decision, and the current verified status of the core. |
| [isa-tests.md](isa-tests.md) | The self-checking RV32E assembly ISA suite: what each test covers, the pass/fail protocol, and how to run it. |
| [simulation.md](simulation.md) | The two cocotb environments (core-level pyuvm ISA suite + top-level integration), how they are wired, and how to run them. |
| [firmware-workflow.md](firmware-workflow.md) | The Harvard memory map, the C runtime (crt0/linker/elf2hex), and the create → build → icebram-patch → flash loop. |

See also the top-level [README.md](../README.md) and the firmware
[sw/README.md](../sw/README.md).

## Status snapshot

Last verified on this working tree (commit `d3fcbad`):

| Item | Result |
|------|--------|
| Core-level ISA suite (`make test`) | **12 / 12 PASS** |
| Top-level UART integration (`make test-top APP=hello_uart`) | **PASS** — emits `Hello from RV32E!` |
| Top-level timer (`make test-top APP=timer_blink`) | **PASS** — periods `[50000]×5`, drift 0 |
| Timing (`clk_core`, target 40 MHz) | **41.10 MHz** (PASS, +1.10 MHz) |
| Logic cells (LUT/FF) | 3303 / 7680 (43.0 %) |
| Block RAM | 20 / 32 (62.5 %) |
| Global buffers / PLL | 4 / 8 · 1 / 2 |

> These numbers come from `make test`, `make test-top` and `make report` on
> this tree; regenerate them after RTL changes.
