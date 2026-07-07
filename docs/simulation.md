# Simulation (cocotb)

The design is verified with two **cocotb** environments, both driven by Icarus
Verilog:

| Environment | DUT | Purpose |
|-------------|-----|---------|
| [sim/cocotb](../sim/cocotb) | `rv32e_core` (core only) | The RV32E **ISA suite** — a pyuvm testbench that compiles each assembly test, runs it against a memory-model BFM, and checks `tohost`. |
| [sim/cocotb_top](../sim/cocotb_top) | `top` (full SoC) | **Integration** — runs a real C application on the actual `top.v`, PLL bypassed, and observes the external pins (UART, timer). |

Requirements: `iverilog` (from oss-cad-suite), `cocotb >= 2.0`, `pyuvm >= 4.0`,
and the RISC-V GCC (`riscv-none-elf-gcc`).

> **PYTHONPATH note.** oss-cad-suite's bundled Python (`tabbypy3`) has a private
> `sys.path` that excludes the user site-packages where `pyuvm` lives. Both
> cocotb Makefiles inject `~/.local/lib/python3.11/site-packages` (and the test
> directory) into `PYTHONPATH` so the simulator can import `pyuvm` and the local
> modules. If you see `ModuleNotFoundError: pyuvm`, that path is the culprit.

---

## Core-level ISA environment (`sim/cocotb`)

This is a proper **pyuvm** testbench wrapped around a lightweight bus-functional
model. It has no dependency on `top.v` or the peripherals — it drives the core's
IMEM/DMEM ports directly.

### Component map

```
tests.py            env.py (pyuvm hierarchy)                 bfm.py + mem_model.py
──────────          ───────────────────────                 ─────────────────────
@cocotb.test  ──►   CpuEnv
  test_add            └─ CpuAgent
  test_irq                 ├─ CpuDriver ─ loads hex, starts BFM, drives reset ─►  CpuBFM
   ...                     │                                                        ├─ Clock (10 ns)
                           ├─ ToHostMonitor ◄─ tohost_q ◄──────────────────────────┤─ _serve_imem  (1-cyc read)
                           │                                                        ├─ _serve_dmem  (1-cyc read + BE write)
                           └─ (via CpuEnv) CpuScoreboard  ◄─ analysis port          └─ _pulse_irq   (external IRQ)
                                    checks PASS / FAIL / TIMEOUT
```

Sources: [tests.py](../sim/cocotb/tests.py), [env.py](../sim/cocotb/env.py),
[bfm.py](../sim/cocotb/bfm.py), [mem_model.py](../sim/cocotb/mem_model.py).

### How one test runs

1. **Compile on the fly.** `BaseRv32Test.run_phase` calls `compile_firmware`,
   which invokes `riscv-none-elf-gcc` (`-march=rv32e_zicsr -mabi=ilp32e`,
   linked with [sw/link.ld](../sw/link.ld)) then `scripts/elf2hex.py` to produce
   a 1024-word `firmware.hex`. A zero `data.hex` initialises DMEM. Everything is
   built in a fresh temp dir — nothing is checked in.
2. **Load the memory models.** The `CpuDriver` loads `firmware.hex` into the IMEM
   model and `data.hex` into the DMEM model, then starts the BFM and drives
   reset.
3. **Serve memory.** The BFM models the **synchronous BRAM** behaviour of real
   hardware: after each rising edge it drives `imem_rdata = imem[addr]` and
   `dmem_rdata = dmem[addr]`, so the DUT samples valid data on the *next* edge
   (1-cycle latency). DMEM writes honour the 4-bit byte enables.
4. **Detect `tohost`.** A write to the last DMEM word (`0x1FFC`) is pushed onto
   `tohost_q`. The `ToHostMonitor` forwards it to the `CpuScoreboard`, which maps
   `1 → PASS` and anything else → `FAIL at case (value>>1)`. No write before the
   timeout → `TIMEOUT`.
5. **External IRQ (optional).** If the test sets `irq_cycle > 0`, the BFM pulses
   the `irq` pin for one cycle at that cycle count. Only `irq` uses this
   (`irq_cycle = 30`); the machine `timer_irq` input is tied to 0 here.

See [isa-tests.md](isa-tests.md) for the list of tests and the pass/fail
protocol, and for how to run them.

```bash
make test                     # all 12 (delegates to sim/cocotb)
make test TESTS=irq           # subset → COCOTB_TEST_FILTER
make -C sim/cocotb            # run the cocotb Makefile directly
```

Build artifacts land in `build/sim_cocotb/`.

---

## Top-level integration environment (`sim/cocotb_top`)

This one instantiates the **whole `top.v`** — CPU, IMEM, DROM/DRAM split,
address decode and all three peripherals — and checks behaviour at the external
pins. It is the pre-silicon proof that the firmware flow and peripherals work end
to end.

Sources: [test_top.py](../sim/cocotb_top/test_top.py),
[Makefile](../sim/cocotb_top/Makefile).

Key mechanics:

- **PLL bypassed.** Compiled with `-DSIM_NO_PLL`, so `top.v` drives the core
  straight from `clk` and pulses `LOCK` once (the `SB_PLL40_CORE` has no
  behavioural model). The test clock is 25 ns → 40 MHz.
- **Firmware pre-loaded via `$readmemh`.** The Makefile builds the selected app
  (`make -C .. APP=<app> firmware`) and stages `firmware.hex`/`drom.hex` as the
  `imem_seed.hex`/`drom_seed.hex` init files `top.v` reads at time 0 — the same
  images `icebram` would patch into hardware.
- **App selection** via `APP=` (default `hello_uart`). Each test is `skip`-ped
  unless its app is active.

### The two tests

| Test | Active when | What it checks |
|------|-------------|----------------|
| `test_uart_output` | `APP ∈ {hello_uart, echo}` | Decodes the 8N1 `uart_tx` stream bit-by-bit (sampling each bit at its centre, `BIT_CYCLES = 40e6/115200`) and asserts the exact banner — e.g. `Hello from RV32E!\r\n`. |
| `test_timer_blink` | `APP == timer_blink` | Watches `mtimer0.timer_irq` rising edges (the interrupt grid), measures 5 consecutive periods, and asserts **every period == `INTERVAL` (50000)** with **zero cumulative drift** — proving the drift-free re-arm. |

```bash
make test-top APP=hello_uart    # UART banner check (default app)
make test-top APP=echo          # UART "echo ready" banner
make test-top APP=timer_blink   # machine-timer drift check
```

Build artifacts land in `build/sim_cocotb_top/`; the staged `imem_seed.hex` /
`drom_seed.hex` are written into `sim/cocotb_top/` and cleaned by
`make -C sim/cocotb_top clean`.

---

## Legacy Icarus smoke-test

A pre-cocotb Verilog testbench, [sim/tb_rv32e.v](../sim/tb_rv32e.v), still exists
for a quick offline check driven by `sw/start.S`:

```bash
make sim            # iverilog + vvp, runs sw/start.S to a tohost PASS
```

It is kept for convenience; the cocotb suites are the authoritative
verification.
