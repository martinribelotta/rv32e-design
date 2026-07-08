# RV32I on iCE40HX4K LQFP144
# Tools: yosys, nextpnr-ice40, icestorm, riscv32-unknown-elf-gcc, iverilog

PROJ     := rv32e
DEVICE   := hx4k
PACKAGE  := tq144   # LQFP144
PCF      := constraints/ice40hx4k_lqfp144.pcf
FREQ     := 40

BUILD := build
SW_BUILD := $(BUILD)/sw

# Yosys synthesis flags for iCE40
# -dffe_min_ce_use 40: only extract a clock-enable when it feeds >=40 FFs.
# Keeps the 32-bit CSR write-enables as data-path LUT muxes instead of CE pins,
# so nextpnr no longer promotes them to the scarce global network (frees 3 SB_GB).
YOSYS_FLAGS := -p "synth_ice40 -top top -dffe_min_ce_use 40 -json $(BUILD)/$(PROJ).json"

# nextpnr flags
PNR_FLAGS := --hx4k --package tq144 \
             --json $(BUILD)/$(PROJ).json \
             --pcf $(PCF) \
             --asc $(BUILD)/$(PROJ).asc \
             --freq $(FREQ)

# RTL sources
RTL_SRCS := rtl/rv32e_pkg.v \
            rtl/bram_dp.v \
            rtl/imem_rom.v \
            rtl/mem_2r1w.v \
            rtl/alu.v \
            rtl/regfile.v \
            rtl/decoder.v \
            rtl/rv32e_core.v \
            rtl/gpio.v \
            rtl/uart.v \
            rtl/mtimer.v \
            rtl/top.v

# Simulation sources (top.v excluded: contains SB_PLL40_CORE FPGA primitive)
# imem_rom.v excluded: tb_rv32e instantiates bram_dp directly for IMEM
SIM_SRCS := rtl/rv32e_pkg.v \
            rtl/bram_dp.v \
            rtl/alu.v \
            rtl/regfile.v \
            rtl/decoder.v \
            rtl/rv32e_core.v \
            sim/tb_rv32e.v

# Software toolchain
RISCV_PREFIX := riscv-none-elf-
CC      := $(RISCV_PREFIX)gcc
AS      := $(RISCV_PREFIX)gcc
LD      := $(RISCV_PREFIX)ld
OBJCOPY := $(RISCV_PREFIX)objcopy

# Firmware app to build/flash — lives in sw/apps/<APP>.
# Override on the command line:  make APP=hello_uart flash-fw
APP ?= blink
APP_DIR := sw/apps/$(APP)

# C firmware build flags. RV32E has no hardware mul/div, so -lgcc supplies the
# soft routines. -msmall-data-limit=0 keeps everything in .data/.bss/.rodata
# (no gp-relative addressing → no global-pointer setup needed in crt0).
CFLAGS := -march=rv32e_zicsr -mabi=ilp32e -Os -ffreestanding \
          -nostdlib -nostartfiles -fno-builtin -msmall-data-limit=0 \
          -ffunction-sections -fdata-sections -Wall -Isw/common
LDFLAGS := -Wl,--gc-sections -T sw/common/firmware.ld

# Shared runtime + the selected app's sources
SW_SRCS := sw/common/crt0.S sw/common/soc.c $(wildcard $(APP_DIR)/*.c)

# Assembly-only flags for the legacy iverilog smoke-test (sw/start.S)
AS_FLAGS := -march=rv32e -mabi=ilp32e -nostdlib

.PHONY: all core synth pnr bitstream fw flash-fw flash-core prog sim firmware report timing test test-top clean FORCE

all: core

# -------------------------------------------------------
# Firmware (software build only) — compiles C app in sw/apps/$(APP)
#   firmware.hex : .text                  → IMEM   (1024 words)
#   drom.hex     : .rodata + .data image  → DROM   (512 words, icebram-patchable)
# DRAM (.bss/.data runtime/stack) is zero-initialised in hardware — no image.
# -------------------------------------------------------
firmware: $(BUILD)/firmware.hex $(BUILD)/drom.hex

# Rebuild the firmware whenever APP changes (.app records the last-built app).
$(BUILD)/.app: FORCE | $(BUILD)
	@echo "$(APP)" | cmp -s - $@ 2>/dev/null || echo "$(APP)" > $@

FORCE:

$(SW_BUILD)/firmware.elf: $(SW_SRCS) sw/common/firmware.ld $(BUILD)/.app | $(SW_BUILD)
	$(CC) $(CFLAGS) $(SW_SRCS) $(LDFLAGS) -o $@ -lgcc

$(BUILD)/firmware.hex: $(SW_BUILD)/firmware.elf | $(BUILD)
	python3 scripts/elf2hex.py $< $@ 0x00000000 1024

$(BUILD)/drom.hex: $(SW_BUILD)/firmware.elf | $(BUILD)
	python3 scripts/elf2hex.py $< $@ 0x00001000 512 0

# IMEM/DROM seeds: random 32-bit words (reproducible PRNG). Random content gives
# every BRAM tile unique init data so icebram can locate and patch the IMEM and
# DROM tiles without re-synthesis. The two seeds use DIFFERENT PRNG seeds (42/99)
# and DIFFERENT depths so the memories never collide. Random init also stops
# Yosys from constant-folding through the BRAMs.
$(BUILD)/imem_seed.hex: | $(BUILD)
	python3 -c "import random; r=random.Random(42); \
	    [print(f'{r.randint(0,0xFFFFFFFF):08x}') for _ in range(1024)]" > $@

$(BUILD)/drom_seed.hex: | $(BUILD)
	python3 -c "import random; r=random.Random(99); \
	    [print(f'{r.randint(0,0xFFFFFFFF):08x}') for _ in range(512)]" > $@

# Yosys resolves $readmemh paths relative to the source file directory (rtl/),
# not the build CWD. Symlinks make the seeds visible from rtl/.
rtl/imem_seed.hex: $(BUILD)/imem_seed.hex
	ln -sf $(abspath $(BUILD)/imem_seed.hex) rtl/imem_seed.hex

rtl/drom_seed.hex: $(BUILD)/drom_seed.hex
	ln -sf $(abspath $(BUILD)/drom_seed.hex) rtl/drom_seed.hex

# -------------------------------------------------------
# Synthesis  (depends on seed; firmware.hex NOT a dependency —
# firmware changes use 'make fw' and do not trigger re-synthesis)
# -------------------------------------------------------
synth: $(BUILD)/$(PROJ).json

$(BUILD)/$(PROJ).json: $(RTL_SRCS) $(BUILD)/imem_seed.hex rtl/imem_seed.hex $(BUILD)/drom_seed.hex rtl/drom_seed.hex | $(BUILD)
	cd $(BUILD) && yosys -q -p "synth_ice40 -top top -dffe_min_ce_use 40 -json $(PROJ).json" $(abspath $(RTL_SRCS))

# -------------------------------------------------------
# Place-and-route
# -------------------------------------------------------
pnr: $(BUILD)/$(PROJ).asc

$(BUILD)/$(PROJ).asc: $(BUILD)/$(PROJ).json $(PCF)
	nextpnr-ice40 $(PNR_FLAGS) --log $(BUILD)/$(PROJ)_pnr.log

# -------------------------------------------------------
# Core bitstream  (full synthesis with current firmware)
# -------------------------------------------------------
core: $(BUILD)/$(PROJ).bin

bitstream: core

$(BUILD)/$(PROJ).bin: $(BUILD)/$(PROJ).asc
	icepack $< $@

# -------------------------------------------------------
# Firmware update via icebram  (~3 s, no re-synthesis)
# Patches IMEM (.text) and DROM (.rodata/.data image) tiles in the existing .asc
# without touching synthesis/PnR. Requires 'make core' to have run at least once.
# -------------------------------------------------------
fw: $(BUILD)/firmware.hex $(BUILD)/drom.hex $(BUILD)/imem_seed.hex $(BUILD)/drom_seed.hex $(BUILD)/$(PROJ).asc
	icebram $(BUILD)/imem_seed.hex $(BUILD)/firmware.hex \
	    < $(BUILD)/$(PROJ).asc       > $(BUILD)/$(PROJ)_fw1.asc
	icebram $(BUILD)/drom_seed.hex $(BUILD)/drom.hex \
	    < $(BUILD)/$(PROJ)_fw1.asc   > $(BUILD)/$(PROJ)_fw.asc
	icepack $(BUILD)/$(PROJ)_fw.asc $(BUILD)/$(PROJ)_fw.bin

flash-fw: fw
	iceprog $(BUILD)/$(PROJ)_fw.bin

flash-core: $(BUILD)/$(PROJ).bin
	iceprog $<

# prog kept as alias for flash-fw (backwards compat)
prog: flash-fw

# -------------------------------------------------------
# Report (reads existing artefacts, no re-synthesis)
# -------------------------------------------------------
report:
	@python3 scripts/report.py $(BUILD) $(PROJ)

timing: $(BUILD)/$(PROJ).asc
	icetime -d $(DEVICE) -P $(PACKAGE) -p $(PCF) -t $<

# -------------------------------------------------------
# Simulation (iverilog + vvp) — quick offline smoke-test.
# Uses sw/start.S (terminates via tohost), independent of the C APP firmware
# (a C app such as blink loops forever and would time out the testbench).
# -------------------------------------------------------
sim: $(BUILD)/sim/tb_rv32e.vvp
	cd $(BUILD)/sim && vvp tb_rv32e.vvp

$(BUILD)/sim/start.elf: sw/start.S sw/link.ld | $(BUILD)/sim
	$(AS) $(AS_FLAGS) -T sw/link.ld sw/start.S -o $@

$(BUILD)/sim/firmware.hex: $(BUILD)/sim/start.elf | $(BUILD)/sim
	python3 scripts/elf2hex.py $< $@ 0x00000000 1024

$(BUILD)/sim/data.hex: | $(BUILD)/sim
	python3 -c "print('00000000\n' * 1024)" > $@

$(BUILD)/sim/tb_rv32e.vvp: $(SIM_SRCS) $(BUILD)/sim/firmware.hex $(BUILD)/sim/data.hex | $(BUILD)/sim
	iverilog -g2005 -I rtl -o $@ $(SIM_SRCS)

# -------------------------------------------------------
# Directories
# -------------------------------------------------------
$(BUILD) $(SW_BUILD) $(BUILD)/sim:
	mkdir -p $@

# -------------------------------------------------------
# Test suite — cocotb + pyuvm
# TESTS=add branch ...  runs only those tests (regex filter)
# -------------------------------------------------------
ifdef TESTS
  # "TESTS=add branch" → COCOTB_TEST_FILTER="test_add|test_branch"
  pipe       := |
  space      := $(empty) $(empty)
  _RAW       := $(subst $(space),$(pipe),$(addprefix test_,$(TESTS)))
  _COCOTB_EXTRA := COCOTB_TEST_FILTER='$(_RAW)'
endif

test:
	$(MAKE) -C sim/cocotb $(_COCOTB_EXTRA)

# Top-level integration test: runs a real C app on top.v and decodes uart_tx.
# Defaults to hello_uart (sim/cocotb_top's own default); pass APP=echo to override.
# (APP=blink — the global default — has no UART output, so it is not forwarded.)
test-top:
	$(MAKE) -C sim/cocotb_top $(if $(filter-out blink,$(APP)),APP=$(APP))

# Legacy iverilog runner (kept for quick offline smoke-tests)
test-iverilog:
	python3 scripts/run_tests.py $(TESTS)

# -------------------------------------------------------
# Clean
# -------------------------------------------------------
clean:
	rm -rf $(BUILD)
	$(MAKE) -C sim/cocotb clean 2>/dev/null || true
	$(MAKE) -C sim/cocotb_top clean 2>/dev/null || true
