# Firmware workflow

How to write, build, and flash firmware for the board — and how the pieces fit
together. The headline feature is **~3-second reflashing without
re-synthesis**: after routing the bitstream once, `icebram` patches the new
program into the already-placed BRAM tiles.

This complements the app-writer's guide in [sw/README.md](../sw/README.md); here
we focus on the *mechanics* of the flow.

## Memory map (what the linker targets)

Harvard architecture — code and data are separate address spaces. Loads/stores
**cannot** reach IMEM.

| Region | Bytes | Holds | Reflash |
|--------|-------|-------|---------|
| IMEM | `0x0000–0x0FFF` (4 KB) | `.text` | icebram |
| DROM | `0x1000–0x17FF` (2 KB) | `.rodata` + `.data` **load image** | icebram |
| DRAM | `0x1800–0x1EFF` (~1.75 KB) | `.data` runtime + `.bss` + stack | zero-init |
| I/O | `0x1F00–0x1FFF` (256 B) | GPIO / UART / mtimer | — |

Why the data side is split into a read-only ROM plus a writable RAM (and not one
RAM) is explained in [architecture.md](architecture.md) (design decision 6): a
byte-writable RAM can't be icebram-patched, so initialised data lives in an
icebram-patchable **DROM** and is copied to **DRAM** at boot.

## The three build ingredients

### 1. `crt0.S` — C startup
[sw/common/crt0.S](../sw/common/crt0.S) runs before `main()`:

1. set `sp` to `__stack_top` (top of DRAM, just below the I/O window);
2. copy `.data` from its DROM load image (`__data_load`) to its DRAM runtime
   address (`__data_start..__data_end`);
3. zero `.bss`;
4. `call main`;
5. on return, write `1` to `tohost` (`0x1FFC`) — a PASS marker for the
   simulator, dropped harmlessly by the hardware decode — then spin.

### 2. `firmware.ld` — linker script
[sw/common/firmware.ld](../sw/common/firmware.ld) places `.text` in IMEM,
`.rodata` in DROM, and `.data` with its **VMA in DRAM but LMA in DROM**
(`> DRAM AT> DROM`), exporting `__data_load = LOADADDR(.data)` for `crt0`. `.bss`
and the stack live in DRAM. A linker `ASSERT` fails the build if the DROM image
(`.rodata` + `.data` load image) exceeds 2 KB.

### 3. `elf2hex.py` — ELF → `$readmemh`
[scripts/elf2hex.py](../scripts/elf2hex.py) converts the ELF to a word-addressed
hex image, placing each segment by its **load address (`p_paddr`/LMA)** — this is
what makes `.data`'s init image land in DROM. Unused IMEM words are filled with
`jal x0,0` (`0x6F`) so blank tiles stay non-zero (helps `icebram` distinguish
IMEM from all-zero tiles). The Makefile calls it twice:

| Output | Segment | Target | Words |
|--------|---------|--------|-------|
| `build/firmware.hex` | `.text` | IMEM | 1024 |
| `build/drom.hex` | `.rodata` + `.data` load image | DROM | 512 |

## The reflash mechanism (`icebram`)

IMEM and DROM are seeded at synthesis with **reproducible random** patterns
(`build/imem_seed.hex`, `build/drom_seed.hex`; distinct PRNG seeds and depths).
Random content gives every BRAM tile unique init data, so `icebram` can find and
replace exactly those tiles in the routed `.asc` — and it stops yosys
constant-folding through the memories. `make fw` runs **two** icebram passes
(IMEM then DROM) on the existing `.asc`, re-packs, and is done in seconds. No
synthesis, no place-and-route. See the `fw` target in the [Makefile](../Makefile).

## The workflow

### One time: route a bitstream onto the board

```bash
make core          # yosys synth + nextpnr pnr + icepack  (~20 s)
make flash-core    # iceprog the full bitstream once
```

### Every iteration: edit C, reflash in ~3 s

```bash
make flash-fw APP=hello_uart    # build app → icebram-patch IMEM+DROM → iceprog
```

`APP` selects a directory under [sw/apps/](../sw/apps) and defaults to `blink`.
`make fw APP=<name>` produces the patched `build/rv32e_fw.bin` without
programming; `make firmware APP=<name>` only builds the hex images. You can also
work from inside an app dir (`cd sw/apps/hello_uart && make flash-fw`), a thin
wrapper over the root Makefile.

For `hello_uart` / `echo`, open a serial terminal at **115200 8N1**.

### Command reference

| Command | Effect |
|---------|--------|
| `make core` / `make bitstream` | Full flow → `build/rv32e.bin` (needs re-synth) |
| `make flash-core` | Program the full bitstream |
| `make firmware APP=<a>` | Build `firmware.hex` + `drom.hex` only |
| `make fw APP=<a>` | icebram-patch IMEM+DROM → `build/rv32e_fw.bin` |
| `make flash-fw APP=<a>` | `fw` + program the board (~3 s) |
| `make test-top APP=<a>` | Simulate the app on `top.v` (see [simulation.md](simulation.md)) |
| `make timing` / `make report` | icetime report / utilisation summary |

## Writing a new app

1. `cp -r sw/apps/template sw/apps/myapp`, edit `main.c`, set `APP := myapp` in
   its `Makefile`.
2. Use the helpers in [sw/common/soc.h](../sw/common/soc.h): `uart_puts`,
   `uart_getc`, `gpio_write`, `mtime_now`, `delay_us`, the `csr_*` macros, etc.
3. `make flash-fw APP=myapp`.

**Size budget** (asserted/limited by hardware): `.text` ≤ 4 KB,
`.rodata + .data` load image ≤ 2 KB, `.data + .bss + stack` ≤ ~1.75 KB.
Toolchain: `riscv-none-elf-gcc`, `-march=rv32e_zicsr -mabi=ilp32e`; `-lgcc`
supplies the software mul/div routines RV32E lacks.

## Using the machine timer

The CLINT-style timer (`0x1F50`) gives precise timing and periodic interrupts:

- **Delays / timestamps:** `mtime_now()`, `delay_us()`, `delay_ms()` read the
  free-running 64-bit `mtime` instead of guessing a busy-wait count.
- **Periodic interrupts:** set `mtimecmp`, install a handler in `mtvec`, enable
  `mie.MTIE` + `mstatus.MIE`. Re-arm in the ISR **relative to the deadline that
  fired** — `mtimer_set_cmp(mtimer_get_cmp() + INTERVAL)` — for an exact,
  drift-free period (re-arming with `mtime_now() + INTERVAL` would drift by the
  interrupt-entry latency). See [sw/apps/timer_blink/main.c](../sw/apps/timer_blink/main.c);
  the `timer_blink` top-level test asserts zero accumulated drift.
