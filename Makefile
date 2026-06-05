# RV32I on iCE40HX4K LQFP144
# Tools: yosys, nextpnr-ice40, icestorm, riscv32-unknown-elf-gcc, iverilog

PROJ     := rv32i
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
RTL_SRCS := rtl/rv32i_pkg.v \
            rtl/bram_dp.v \
            rtl/alu.v \
            rtl/regfile.v \
            rtl/decoder.v \
            rtl/rv32i_core.v \
            rtl/top.v

# Simulation sources (top.v excluded: contains SB_PLL40_CORE FPGA primitive)
SIM_SRCS := rtl/rv32i_pkg.v \
            rtl/bram_dp.v \
            rtl/alu.v \
            rtl/regfile.v \
            rtl/decoder.v \
            rtl/rv32i_core.v \
            sim/tb_rv32i.v

# Software toolchain
RISCV_PREFIX := riscv-none-elf-
AS    := $(RISCV_PREFIX)gcc
LD    := $(RISCV_PREFIX)ld
OBJCOPY := $(RISCV_PREFIX)objcopy
AS_FLAGS := -march=rv32e -mabi=ilp32e -nostdlib

.PHONY: all synth pnr bitstream prog sim firmware report timing test clean

all: bitstream

# -------------------------------------------------------
# Firmware
# -------------------------------------------------------
firmware: $(BUILD)/firmware.hex $(BUILD)/data.hex

$(SW_BUILD)/firmware.elf: sw/start.S sw/link.ld | $(SW_BUILD)
	$(AS) $(AS_FLAGS) -T sw/link.ld sw/start.S -o $@

$(BUILD)/firmware.hex: $(SW_BUILD)/firmware.elf | $(BUILD)
	python3 scripts/elf2hex.py $< $@ 0x00000000 1024

$(BUILD)/data.hex: | $(BUILD)
	python3 -c "print('00000000\n' * 1024)" > $@

# -------------------------------------------------------
# Synthesis
# -------------------------------------------------------
synth: firmware $(BUILD)/$(PROJ).json

$(BUILD)/$(PROJ).json: $(RTL_SRCS) $(BUILD)/firmware.hex $(BUILD)/data.hex | $(BUILD)
	cd $(BUILD) && yosys -q -p "synth_ice40 -top top -json $(PROJ).json" $(abspath $(RTL_SRCS))

# -------------------------------------------------------
# Place-and-route
# -------------------------------------------------------
pnr: $(BUILD)/$(PROJ).asc

$(BUILD)/$(PROJ).asc: $(BUILD)/$(PROJ).json $(PCF)
	nextpnr-ice40 $(PNR_FLAGS) --log $(BUILD)/$(PROJ)_pnr.log

# -------------------------------------------------------
# Bitstream
# -------------------------------------------------------
bitstream: $(BUILD)/$(PROJ).bin

$(BUILD)/$(PROJ).bin: $(BUILD)/$(PROJ).asc
	icepack $< $@

# -------------------------------------------------------
# Report (reads existing artefacts, no re-synthesis)
# -------------------------------------------------------
report:
	@python3 scripts/report.py $(BUILD) $(PROJ)

timing: $(BUILD)/$(PROJ).asc
	icetime -d $(DEVICE) -P $(PACKAGE) -p $(PCF) -t $<

# -------------------------------------------------------
# Programming (via iceprog)
# -------------------------------------------------------
prog: $(BUILD)/$(PROJ).bin
	iceprog $<

# -------------------------------------------------------
# Simulation (iverilog + vvp)
# -------------------------------------------------------
sim: firmware $(BUILD)/sim/tb_rv32i.vvp
	cd $(BUILD)/sim && vvp tb_rv32i.vvp

$(BUILD)/sim/tb_rv32i.vvp: $(SIM_SRCS) $(BUILD)/firmware.hex | $(BUILD)/sim
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
