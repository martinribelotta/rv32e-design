# RV32E CPU on iCE40HX4K

A minimal RV32E soft-core processor targeting the iCE40HX4K (LQFP144) FPGA,
verified with a cocotb/pyuvm test environment and deployable via icebram
fast-firmware-update (no re-synthesis needed after the first build).

## Processor features

- **Architecture**: RV32E (32-bit, 16 general-purpose registers x0–x15)
- **Pipeline**: 3-stage (IF → ID/EX → MEM/WB) with full data-hazard
  forwarding and load-use stall
- **Control flow**: BEQ/BNE/BLT/BGE/BLTU/BGEU, JAL, JALR; branches resolved
  in ID/EX with a one-cycle penalty
- **ALU**: ADD/ADDI/SUB, SLL/SRL/SRA and immediate variants, SLT/SLTU,
  AND/OR/XOR and immediate variants, LUI, AUIPC
- **Loads/stores**: LB/LBU/LH/LHU/LW, SB/SH/SW with byte-enable DMEM writes
- **CSRs**: `mstatus`, `mie`, `mtvec`, `mepc`, `mcause`, `mcycle`,
  `mcycleh` — machine-mode only
- **Interrupts**: single external IRQ pin, machine-mode trap and mret
- **Target**: iCE40HX4K LQFP144, 40 MHz (SB\_PLL40\_CORE)

## Memory map

| Region | Word addresses | Byte addresses | Size |
|--------|---------------|----------------|------|
| IMEM (BRAM) | 0x000–0x3FF | 0x0000–0x0FFC | 4 KB |
| DMEM (BRAM) | 0x000–0x3BF | 0x1000–0x1EFC | ~3.75 KB |
| Peripheral I/O | 0x3C0–0x3FF | 0x1F00–0x1FFF | 256 B |

### Peripheral registers (word addresses)

| Address | Register |
|---------|----------|
| 0x3C0 | GPIO OUT |
| 0x3C1 | GPIO IN (read-only) |
| 0x3C2 | GPIO DIR (1 = output) |
| 0x3D0 | UART DATA (write = TX byte, read = RX byte) |
| 0x3D1 | UART STATUS (bit 0 = TX busy, bit 1 = RX valid) |
| 0x3D2 | UART BAUD divisor (default 346 → 115200 baud @ 40 MHz) |
| 0x3FF | tohost (1 = PASS, (n<<1)\|1 = FAIL at test case n) |

GPIO is 8-bit wide with a 2-FF input synchroniser.
UART is 8N1 with a runtime-configurable baud divisor.

## Project layout

```
rv32i-base/
├── Makefile
├── constraints/
│   └── ice40hx4k_lqfp144.pcf
├── rtl/
│   ├── rv32e_pkg.v      # opcodes and constants
│   ├── bram_dp.v        # inferred dual-port BRAM primitive
│   ├── imem_rom.v       # IMEM wrapper (enables icebram patching)
│   ├── alu.v
│   ├── regfile.v        # 16-entry RV32E register file
│   ├── decoder.v
│   ├── rv32e_core.v     # 3-stage pipeline core
│   ├── gpio.v           # 8-bit GPIO peripheral
│   ├── uart.v           # 8N1 UART peripheral
│   └── top.v            # top-level: PLL, BRAMs, peripheral bus
├── sim/
│   ├── tb_rv32e.v       # legacy iverilog testbench
│   └── cocotb/          # cocotb + pyuvm verification environment
│       ├── Makefile
│       ├── mem_model.py
│       ├── bfm.py       # Bus Functional Model (clock, reset, IMEM/DMEM)
│       ├── env.py       # pyuvm hierarchy (agent, driver, monitor, scoreboard)
│       └── tests.py     # 12 @cocotb.test() entry points
├── scripts/
│   ├── elf2hex.py       # ELF → $readmemh hex converter
│   ├── run_tests.py     # legacy iverilog test runner
│   └── report.py        # synthesis report parser
├── sw/
│   ├── start.S          # boot firmware example
│   └── link.ld          # linker script (IMEM @ 0x0, DMEM @ 0x1000)
└── tests/               # RV32E assembly test cases
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

```bash
make firmware      # compile sw/start.S → build/firmware.hex
make synth         # yosys synthesis → build/rv32e.json
make pnr           # nextpnr place-and-route → build/rv32e.asc
make bitstream     # icepack → build/rv32e.bin  (full flow)
make fw            # icebram firmware patch (~3 s, no re-synthesis)
make flash-core    # program full bitstream with iceprog
make flash-fw      # program firmware-patched bitstream with iceprog
make prog          # alias for flash-fw
make timing        # icetime timing report
make report        # utilisation summary from yosys/nextpnr logs
make sim           # legacy iverilog simulation
make test          # cocotb + pyuvm test suite (all 12 tests)
make clean
```

### Running a subset of tests

```bash
# single test
make test TESTS=add

# multiple tests (space-separated; matched as a regex OR)
make test TESTS="add branch irq"
```

## Firmware update flow

After an initial `make bitstream`, firmware can be updated in ~3 seconds
without re-synthesis using icebram:

```bash
# edit sw/start.S (or link your own application)
make flash-fw
```

IMEM is seeded with a reproducible random pattern (`build/imem_seed.hex`)
so icebram can locate the IMEM tiles unambiguously even when DMEM and the
register file are all-zero.

## Test suite

The cocotb/pyuvm environment compiles each assembly test on-the-fly,
loads it into the BFM memory model, applies reset, and checks the value
written to the `tohost` address at the end of DMEM:

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
make -C sim/cocotb                              # run all 12 tests
make -C sim/cocotb COCOTB_TEST_FILTER=test_irq  # run one test
```

## License

MIT
