# RV32E CPU on iCE40HX4K

A minimal RV32E soft-core processor targeting the iCE40HX4K (LQFP144) FPGA,
verified with a cocotb/pyuvm test environment and deployable via icebram
fast-firmware-update (no re-synthesis needed after the first build).

📖 In-depth design docs live in **[docs/](docs/)** — architecture & design
decisions, the ISA test suite, the cocotb simulation setup, and the firmware
build/flash workflow.

## Processor features

- **Architecture**: RV32E (32-bit, 16 general-purpose registers x0–x15)
- **Pipeline**: 3-stage (IF → ID/EX → MEM/WB) with full data-hazard
  forwarding and load-use stall
- **Control flow**: BEQ/BNE/BLT/BGE/BLTU/BGEU, JAL, JALR; branches resolved
  in ID/EX with a one-cycle penalty
- **ALU**: ADD/ADDI/SUB, SLL/SRL/SRA and immediate variants, SLT/SLTU,
  AND/OR/XOR and immediate variants, LUI, AUIPC
- **Loads/stores**: LB/LBU/LH/LHU/LW, SB/SH/SW with byte-enable DMEM writes
- **CSRs**: `mstatus`, `mie`, `mip`, `mtvec`, `mepc`, `mcause`, `mcycle`,
  `mcycleh` — machine-mode only
- **Interrupts**: machine external (MEI, cause 11) and machine timer
  (MTI, cause 7), each gated by its `mie` bit and `mstatus.MIE`, with
  trap/`mret`. A CLINT-style `mtime`/`mtimecmp` peripheral drives MTIP;
  the external IRQ pin is present in the core but tied off in `top.v`.
- **Target**: iCE40HX4K LQFP144, 50 MHz input → 40 MHz core (SB\_PLL40\_CORE)

## Memory map

Harvard architecture: instructions live in IMEM and are **not** readable by
load instructions; all constants and variables live on the separate data bus.
All three banks are packaged in one **2R1W** memory block, `mem_2r1w`
(read port 0 = instructions, read port 1 = data, write port = data-only); on
iCE40 each read port gets its own bank, which keeps the instruction bank
write-free and therefore icebram-patchable.

| Region | Byte addresses | Size | Contents | Reflash |
|--------|---------------|------|----------|---------|
| IMEM (BRAM) | 0x0000–0x0FFF | 4 KB | `.text` | icebram |
| DROM (BRAM) | 0x1000–0x17FF | 2 KB | `.rodata` + `.data` load image | icebram |
| DRAM (BRAM) | 0x1800–0x1EFF | ~1.75 KB | `.data` runtime + `.bss` + stack | zero-init |
| Peripheral I/O | 0x1F00–0x1FFF | 256 B | GPIO / UART / mtimer | — |

`.data` initial values are stored in the read-only DROM and copied to DRAM by
`crt0` at boot; `.bss` is zeroed. IMEM and DROM are random-seeded at synthesis
so `icebram` can locate and patch their BRAM tiles without re-synthesis; DRAM
is a plain zero-initialised RAM.

### Peripheral registers

| Byte addr | Register |
|-----------|----------|
| 0x1F00 | GPIO OUT (R/W) |
| 0x1F04 | GPIO IN (read-only) |
| 0x1F08 | GPIO DIR (1 = output) |
| 0x1F40 | UART DATA (write = TX byte, read = RX byte, clears rx_valid) |
| 0x1F44 | UART STATUS (bit 0 = TX ready, bit 1 = RX valid) |
| 0x1F48 | UART BAUD divisor (default 346 → 115200 baud @ 40 MHz) |
| 0x1F50 | MTIME [31:0]    (R/W, free-running 64-bit @ 40 MHz) |
| 0x1F54 | MTIME [63:32] |
| 0x1F58 | MTIMECMP [31:0] (R/W → MTIP asserted while mtime ≥ mtimecmp) |
| 0x1F5C | MTIMECMP [63:32] |

GPIO is 8-bit wide with a 2-FF input synchroniser (mapped to LEDs/buttons).
UART is 8N1 with a runtime-configurable baud divisor. The machine timer is
CLINT-style: firmware re-arms the interrupt by writing a larger `mtimecmp`.

> **Simulation convention:** on `main()` return, `crt0` writes `1` to the
> `tohost` word at `0x1FFC`; the testbench reads this as **PASS**
> (`(n<<1)|1` = FAIL at case *n*). It is a harmless no-op on real hardware.

## Project layout

```
rv32i-base/
├── Makefile
├── constraints/
│   └── ice40hx4k_lqfp144.pcf
├── rtl/
│   ├── rv32e_pkg.v      # opcodes, ALU/CSR/branch constants
│   ├── bram_dp.v        # inferred dual-port BRAM primitive
│   ├── imem_rom.v       # single-port ROM wrapper (icebram-patchable)
│   ├── mem_2r1w.v       # unified 2R1W memory: instr read + data read/write
│   ├── alu.v
│   ├── regfile.v        # 16-entry RV32E register file (sync read)
│   ├── decoder.v
│   ├── rv32e_core.v     # 3-stage pipeline core (+ branch unit)
│   ├── gpio.v           # 8-bit GPIO peripheral
│   ├── uart.v           # 8N1 UART peripheral
│   ├── mtimer.v         # CLINT-style machine timer (mtime/mtimecmp → MTIP)
│   └── top.v            # top level: PLL, mem_2r1w (IMEM/DROM/DRAM), peripheral bus
├── sw/                  # C + assembly firmware — see sw/README.md
│   ├── common/          # crt0.S, firmware.ld, soc.c/.h shared runtime
│   ├── apps/            # blink, hello_uart, echo, timer_blink, template
│   ├── start.S          # legacy asm smoke-test program (make sim)
│   └── link.ld          # legacy linker script for tests/*.S
├── sim/
│   ├── tb_rv32e.v       # legacy iverilog testbench
│   ├── cocotb/          # core-level cocotb + pyuvm env (12 ISA tests)
│   │   ├── Makefile
│   │   ├── mem_model.py
│   │   ├── bfm.py       # Bus Functional Model (clock, reset, IMEM/DMEM)
│   │   ├── env.py       # pyuvm hierarchy (agent, driver, monitor, scoreboard)
│   │   └── tests.py     # 12 @cocotb.test() entry points
│   └── cocotb_top/      # top-level integration test (real C app on top.v)
├── scripts/
│   ├── elf2hex.py       # ELF → $readmemh hex converter
│   ├── run_tests.py     # legacy iverilog test runner
│   └── report.py        # synthesis report parser
└── tests/               # RV32E assembly ISA test cases (*.S)
```

## Requirements

### FPGA toolchain

```
yosys
nextpnr-ice40
icestorm  (icepack, icebram, iceprog, icetime)
```

### RISC-V toolchain

```
riscv-none-elf-gcc  (built with rv32e_zicsr multilib support)
```

### Simulation

```
iverilog / vvp
cocotb >= 2.0  (tested with oss-cad-suite 2.1.0)
pyuvm  >= 4.0
```

## Build targets

The firmware app is selected with `APP=<name>` (an app directory under
`sw/apps/`); it defaults to `blink`.

```bash
# --- FPGA bitstream (full flow, needs synthesis + place-and-route) ---
make core          # synth + pnr + icepack → build/rv32e.bin
make flash-core    # program the full bitstream once with iceprog

# --- firmware iteration (icebram patch, ~3 s, no re-synthesis) ---
make firmware APP=hello_uart   # compile sw/apps/hello_uart → firmware.hex + drom.hex
make fw       APP=hello_uart   # patch IMEM + DROM into the routed bitstream
make flash-fw APP=hello_uart   # patch + program the board

# --- reports & simulation ---
make timing        # icetime timing report
make report        # utilisation summary from yosys/nextpnr logs
make sim           # legacy iverilog smoke-test (sw/start.S)
make test          # cocotb + pyuvm ISA suite (all 12 tests)
make test-top APP=hello_uart   # run a real C app on top.v, decode uart_tx
make clean
```

The individual sub-steps `make synth`, `make pnr` and `make bitstream`
(alias of `core`) are also available. See **[sw/README.md](sw/README.md)**
for the full firmware build/flash workflow and how to write a new app.

### Running a subset of ISA tests

```bash
# single test
make test TESTS=add

# multiple tests (space-separated; matched as a regex OR)
make test TESTS="add branch irq"
```

## Firmware update flow

After an initial `make core`, firmware can be updated in ~3 seconds without
re-synthesis using icebram:

```bash
make flash-fw APP=hello_uart    # build app, patch IMEM+DROM, program board
```

IMEM and DROM are each seeded with a reproducible random pattern
(`build/imem_seed.hex`, `build/drom_seed.hex`) so icebram can locate their
BRAM tiles unambiguously even when DRAM and the register file are all-zero.
Both `.text` (IMEM) and the `.rodata`/`.data` image (DROM) are patched.

## Test suite

Two cocotb environments cover the design:

**Core-level ISA suite** (`sim/cocotb`) — compiles each assembly test
on-the-fly, loads it into the BFM memory model, applies reset, and checks the
value written to the `tohost` address at the end of the data space:

| Test | Instructions covered |
|------|---------------------|
| add | ADD |
| addi | ADDI |
| sub | SUB |
| logical | AND/OR/XOR and immediate forms |
| shift | SLL/SRL/SRA and immediate forms |
| slt | SLT/SLTU and immediate forms |
| lui\_auipc | LUI, AUIPC |
| branch | BEQ/BNE/BLT/BGE/BLTU/BGEU |
| jal\_jalr | JAL, JALR |
| load\_store | LB/LBU/LH/LHU/LW, SB/SH/SW |
| hazard | load-use stall, ALU forwarding |
| irq | external IRQ, mtvec/mstatus/mie/mepc/mret |

```bash
make test                    # run all 12 tests
make test TESTS=irq          # run one test
```

**Top-level integration test** (`sim/cocotb_top`) — builds a real C app and
runs it on the full `top.v` (PLL bypassed via `-DSIM_NO_PLL`), decoding the
`uart_tx` stream. `make test-top APP=hello_uart` checks the board actually
emits `Hello from RV32E!`; `make test-top APP=timer_blink` asserts the
machine-timer interrupt fires with an exact, drift-free period.

## Documentation

| Doc | Contents |
|-----|----------|
| [docs/architecture.md](docs/architecture.md) | Block diagram, the 3-stage pipeline, design decisions, current status, and known limitations. |
| [docs/isa-tests.md](docs/isa-tests.md) | The self-checking RV32E ISA suite and how to run it. |
| [docs/simulation.md](docs/simulation.md) | The two cocotb environments (core-level pyuvm + top-level integration). |
| [docs/firmware-workflow.md](docs/firmware-workflow.md) | Memory map, C runtime, and the icebram build/flash loop. |
| [sw/README.md](sw/README.md) | App-writer's guide for the C firmware. |

## License

MIT
