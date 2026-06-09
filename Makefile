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
YOSYS_FLAGS := -p "synth_ice40 -top top -json $(BUILD)/$(PROJ).json"

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
            rtl/alu.v \
            rtl/regfile.v \
            rtl/decoder.v \
            rtl/rv32e_core.v \
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
AS    := $(RISCV_PREFIX)gcc
LD    := $(RISCV_PREFIX)ld
OBJCOPY := $(RISCV_PREFIX)objcopy
AS_FLAGS := -march=rv32e -mabi=ilp32e -nostdlib

.PHONY: all core synth pnr bitstream fw flash-fw flash-core prog sim firmware report timing test clean

all: core

# -------------------------------------------------------
# Firmware (software build only)
# -------------------------------------------------------
firmware: $(BUILD)/firmware.hex $(BUILD)/data.hex

$(SW_BUILD)/firmware.elf: sw/start.S sw/link.ld | $(SW_BUILD)
	$(AS) $(AS_FLAGS) -T sw/link.ld sw/start.S -o $@

$(BUILD)/firmware.hex: $(SW_BUILD)/firmware.elf | $(BUILD)
	python3 scripts/elf2hex.py $< $@ 0x00000000 1024

$(BUILD)/data.hex: | $(BUILD)
	python3 -c "print('00000000\n' * 1024)" > $@

# IMEM seed: 1024 random 32-bit words (PRNG, seed=42 → reproducible).
# Random content ensures all BRAM tiles have unique init data so icebram
# can locate IMEM tiles without conflicts with DMEM/regfile (all zeros).
# Also prevents Yosys from constant-folding through the BRAM.
$(BUILD)/imem_seed.hex: | $(BUILD)
	python3 -c "import random; r=random.Random(42); \
	    [print(f'{r.randint(0,0xFFFFFFFF):08x}') for _ in range(1024)]" > $@

# Yosys resolves $readmemh paths relative to the source file directory (rtl/),
# not the build CWD. Symlink makes imem_seed.hex visible from rtl/.
rtl/imem_seed.hex: $(BUILD)/imem_seed.hex
	ln -sf $(abspath $(BUILD)/imem_seed.hex) rtl/imem_seed.hex

# -------------------------------------------------------
# Synthesis  (depends on seed; firmware.hex NOT a dependency —
# firmware changes use 'make fw' and do not trigger re-synthesis)
# -------------------------------------------------------
synth: $(BUILD)/$(PROJ).json

$(BUILD)/$(PROJ).json: $(RTL_SRCS) $(BUILD)/imem_seed.hex rtl/imem_seed.hex $(BUILD)/data.hex | $(BUILD)
	cd $(BUILD) && yosys -q -p "synth_ice40 -top top -json $(PROJ).json" $(abspath $(RTL_SRCS))

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
# Replaces IMEM tiles in the existing .asc without touching PnR.
# Requires 'make core' to have been run at least once.
# -------------------------------------------------------
fw: $(BUILD)/firmware.hex $(BUILD)/imem_seed.hex $(BUILD)/$(PROJ).asc
	icebram $(BUILD)/imem_seed.hex $(BUILD)/firmware.hex \
	    < $(BUILD)/$(PROJ).asc > $(BUILD)/$(PROJ)_fw.asc
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
# Simulation (iverilog + vvp)
# -------------------------------------------------------
sim: firmware $(BUILD)/sim/tb_rv32e.vvp
	cd $(BUILD)/sim && vvp tb_rv32e.vvp

$(BUILD)/sim/tb_rv32e.vvp: $(SIM_SRCS) $(BUILD)/firmware.hex | $(BUILD)/sim
	cp $(BUILD)/firmware.hex $(BUILD)/sim/firmware.hex
	cp $(BUILD)/data.hex     $(BUILD)/sim/data.hex
	iverilog -g2005 -I rtl -o $@ $(SIM_SRCS)

# -------------------------------------------------------
# Directories
# -------------------------------------------------------
$(BUILD) $(SW_BUILD) $(BUILD)/sim:
	mkdir -p $@

# -------------------------------------------------------
# Test suite (riscv-tests style, RV32E)
# -------------------------------------------------------
test:
	python3 scripts/run_tests.py $(TESTS)

# -------------------------------------------------------
# Clean
# -------------------------------------------------------
clean:
	rm -rf $(BUILD)
