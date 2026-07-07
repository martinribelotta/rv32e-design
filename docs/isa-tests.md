# ISA test suite

The core is verified instruction-by-instruction by a set of **self-checking
RV32E assembly programs** in [tests/](../tests). Each program exercises one
instruction group, checks its own results against expected values, and signals
the outcome through a single memory write. They run inside the core-level cocotb
environment described in [simulation.md](simulation.md).

## How a test signals pass/fail

Tests use riscv-tests-style macros from
[tests/env/rv32e_test.h](../tests/env/rv32e_test.h). The protocol is a single
word written to the **`tohost`** address at the top of the data space
(`0x00001FFC`, the last DMEM word):

| `tohost` value | Meaning |
|----------------|---------|
| `1` | **PASS** |
| `(n << 1) | 1` | **FAIL** at test case `n` |
| *(never written)* | **TIMEOUT** — the testbench flags it |

The pattern inside each `.S` file:

```asm
    RVTEST_RV32E                 // entry point _start
    RVTEST_CODE_BEGIN
    ...
    li   TESTNUM, 3              // x15 = current sub-test number
    CHECK_REG(x5, 0x1234)       // if x5 != expected → jump to _fail_jump
    ...
    RVTEST_PASS_LABEL            // fall-through: jump over the fail trampoline
    RVTEST_FAIL_TRAMPOLINE       // _fail_jump: writes (TESTNUM<<1)|1 to tohost
    RVTEST_CODE_END              // _pass: writes 1 to tohost, then spins
```

`CHECK_REG` compares a register against an immediate and branches to the shared
fail trampoline on mismatch; the trampoline encodes which sub-test failed into
`tohost`. A test that runs off the end reaches `_pass` and writes `1`.

The scoreboard in the cocotb environment reads that write and turns it into a
cocotb PASS/FAIL (see [simulation.md](simulation.md)).

## The tests

All **12 tests pass** on this tree (`make test` → `TESTS=12 PASS=12 FAIL=0`).

| Test | File | Instructions / behaviour covered |
|------|------|----------------------------------|
| `add` | [add.S](../tests/add.S) | `ADD` |
| `addi` | [addi.S](../tests/addi.S) | `ADDI` |
| `sub` | [sub.S](../tests/sub.S) | `SUB` |
| `logical` | [logical.S](../tests/logical.S) | `AND/OR/XOR` + `ANDI/ORI/XORI` |
| `shift` | [shift.S](../tests/shift.S) | `SLL/SRL/SRA` + immediate forms |
| `slt` | [slt.S](../tests/slt.S) | `SLT/SLTU` + `SLTI/SLTIU` |
| `lui_auipc` | [lui_auipc.S](../tests/lui_auipc.S) | `LUI`, `AUIPC` |
| `branch` | [branch.S](../tests/branch.S) | `BEQ/BNE/BLT/BGE/BLTU/BGEU` |
| `jal_jalr` | [jal_jalr.S](../tests/jal_jalr.S) | `JAL`, `JALR` |
| `load_store` | [load_store.S](../tests/load_store.S) | `LB/LBU/LH/LHU/LW`, `SB/SH/SW` |
| `hazard` | [hazard.S](../tests/hazard.S) | load-use stall + ALU forwarding paths |
| `irq` | [irq.S](../tests/irq.S) | external IRQ: `mtvec`/`mie`/`mstatus`/`mepc`/`mret` |

Notes on coverage:

- **`hazard`** targets the pipeline itself, not an opcode: it forces the
  load-use stall and both forwarding paths (EX/MEM and MEM/WB) and checks the
  arithmetic still comes out right.
- **`irq`** installs a handler in `mtvec`, enables `MEIE` + global `MIE`, then
  spins in a loop while the BFM pulses the external `irq` pin at cycle ~30. The
  handler sets a flag and `mret`s; the test fails if the flag was not set,
  proving the whole trap/return path (including `mepc` correctness). The
  **machine timer** interrupt path is verified separately at the top level — see
  `timer_blink` in [simulation.md](simulation.md).
- CSR read/write plumbing is exercised through the `irq` test's `csrw`/`csrr`
  of `mtvec`/`mie`/`mstatus`.

## Running the tests

From the project root:

```bash
make test                       # all 12 tests
make test TESTS=add             # a single test
make test TESTS="add branch irq"   # a subset (space-separated → regex OR)
```

Under the hood `make test` delegates to [sim/cocotb](../sim/cocotb); the
`TESTS=` list is translated into a `COCOTB_TEST_FILTER` regex. You can also run
the cocotb Makefile directly:

```bash
make -C sim/cocotb                                 # all
make -C sim/cocotb COCOTB_TEST_FILTER=test_irq     # one
```

Each test is compiled on the fly with `riscv-none-elf-gcc`
(`-march=rv32e_zicsr -mabi=ilp32e`) and linked with the flat
[sw/link.ld](../sw/link.ld) (`.text` in IMEM, `.data`/`.bss` in DMEM), so no
prebuilt artifacts are checked in.

## Adding a test

1. Create `tests/foo.S` using the macros from `tests/env/rv32e_test.h`
   (`RVTEST_RV32E`, `TEST_CASE_START`, `CHECK_REG`, `RVTEST_PASS_LABEL`,
   `RVTEST_FAIL_TRAMPOLINE`, `RVTEST_CODE_END`).
2. Register it in [sim/cocotb/tests.py](../sim/cocotb/tests.py): add a
   `BaseRv32Test` subclass pointing at the new `.S` and a matching
   `@cocotb.test()` entry point (set `irq_cycle` if the test needs an external
   IRQ pulse; leave it `0` otherwise).
3. Run `make test TESTS=foo`.
