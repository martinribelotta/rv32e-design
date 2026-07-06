# Firmware (`sw/`)

C (and assembly) firmware for the rv32i-base RV32E SoC. The flow lets you edit C,
rebuild, and reflash the board in **~3 seconds without re-synthesis**, by patching
the program memories in the already-routed bitstream with `icebram`.

## Layout

```
sw/
  common/          shared runtime, linked into every app
    crt0.S         startup: set sp, copy .data (ROM→RAM), zero .bss, call main()
    firmware.ld    linker script (memory map below)
    soc.h          memory-mapped registers + helper prototypes
    soc.c          uart_putc/puts/getc, gpio_*, delay, uart_put_hex
  apps/
    blink/         rotate a lit LED across the 8 GPIO outputs
    hello_uart/    print "Hello from RV32E!" over UART (exercises .rodata)
    echo/          echo UART input back to the sender
    timer_blink/   blink an LED from a machine-timer (MTIP) interrupt
    template/      empty starting point for a new app
  link.ld          legacy linker script for the assembly tests (tests/*.S) — do not remove
  start.S          legacy assembly program used by the iverilog smoke-test (`make sim`)
```

## Memory map (Harvard — code and data are separate)

The CPU fetches instructions from IMEM and **cannot read it with load instructions**,
so all constants and variables live on the data bus:

| Region | Bytes           | Holds                                   | Reflash |
|--------|-----------------|-----------------------------------------|---------|
| IMEM   | `0x0000–0x0FFF` | `.text` (≤ 4 KB)                        | icebram |
| DROM   | `0x1000–0x17FF` | `.rodata` + `.data` load image (≤ 2 KB) | icebram |
| DRAM   | `0x1800–0x1EFF` | `.data` (runtime) + `.bss` + stack (≤ ~1.75 KB) | zero-init |
| I/O    | `0x1F00–0x1FFF` | GPIO / UART / mtimer (see `soc.h`)      | —       |

`.data` initial values are stored in the read-only DROM and copied to DRAM by `crt0`
at boot; `.bss` is zeroed by `crt0`. Both DROM and IMEM are random-seeded at synthesis
so `icebram` can locate and replace them; DRAM is plain zero-initialised RAM.

## Timing & the machine timer (mtimer)

A CLINT-style machine timer is mapped at `0x1F50` (see [common/soc.h](common/soc.h)):
a free-running 64-bit `mtime` (one tick per 40 MHz clk) and a 64-bit `mtimecmp`. When
`mtime >= mtimecmp` the core takes a **machine timer interrupt** (MTIP, `mcause`
`0x80000007`, enabled by `mie.MTIE` bit 7 + `mstatus.MIE`).

- **Precise delays / timestamps:** `mtime_now()`, `delay_us()`, `delay_ms()` use `mtime`
  instead of a guessed busy-wait loop.
- **Periodic interrupts:** set `mtimecmp`, install a handler in `mtvec`, enable `mie.MTIE`.
  Re-arm in the ISR relative to the deadline that fired (`mtimecmp += INTERVAL`, i.e.
  `mtimer_set_cmp(mtimer_get_cmp() + INTERVAL)`) so the grid is **exact and drift-free** —
  the period is exactly `INTERVAL` regardless of interrupt-entry latency. Re-arming with
  `mtime_now() + INTERVAL` instead would drift by that latency. See
  [apps/timer_blink/main.c](apps/timer_blink/main.c); `make test-top APP=timer_blink`
  asserts the interrupt period is exactly `INTERVAL` with zero accumulated drift.

## Build & flash

One-time, to route a bitstream template onto the FPGA:

```sh
make core          # synth + place-and-route + pack (~20 s)
make flash-core    # program the full bitstream once
```

Then iterate on firmware — **no re-synthesis**, ~3 s each:

```sh
make flash-fw APP=hello_uart    # build app, icebram-patch IMEM+DROM, program board
```

Or from inside an app directory (thin wrapper around the root Makefile):

```sh
cd sw/apps/hello_uart
make            # build firmware images
make flash-fw   # patch + program
```

`APP` defaults to `blink`. `make fw APP=<name>` builds the patched bitstream
(`build/rv32e_fw.bin`) without programming.

For `hello_uart` / `echo`, open a serial terminal at **115200 8N1**.

## Writing a new app

1. `cp -r sw/apps/template sw/apps/myapp` and edit `main.c` (and set `APP := myapp`
   in its `Makefile`).
2. Use the helpers in [common/soc.h](common/soc.h): `uart_puts`, `uart_getc`,
   `gpio_write`, `delay`, …
3. `make flash-fw APP=myapp`.

Constraints: RV32E (no hardware mul/div — `libgcc` provides software routines),
`.text` ≤ 4 KB, `.rodata + .data` ≤ 2 KB, `.data + .bss + stack` ≤ ~1.75 KB.
The linker script asserts if the DROM image overflows.

## Notes

- Toolchain: `riscv-none-elf-gcc`, `-march=rv32e_zicsr -mabi=ilp32e`.
- On `main()` return, `crt0` writes `1` to `tohost` (`0x1FFC`); this is observed as
  PASS by the simulator and is harmless on hardware.
- `make test` and `make sim` run the assembly tests in `tests/` and `start.S`.
- `make test-top` runs a real C app on the full `top.v` in cocotb (PLL bypassed via
  `-DSIM_NO_PLL`) and decodes the `uart_tx` stream — e.g. it checks that `hello_uart`
  actually emits `Hello from RV32E!`. Use `make test-top APP=echo` for the echo banner.
  This is the pre-silicon check that the DROM/DRAM split + UART work end to end.
