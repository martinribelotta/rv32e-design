# cocotb top-level integration test: runs a real C app on top.v and decodes
# the UART TX stream. The PLL is bypassed in sim via -DSIM_NO_PLL.
#
# Usage:
#   make                 — build APP firmware, simulate top.v, check UART output
#   make APP=hello_uart  — choose the app under test (default: hello_uart)

SIM           ?= icarus
TOPLEVEL_LANG  = verilog
ROOT          := $(abspath ../..)
APP           ?= hello_uart

VERILOG_SOURCES = \
    $(ROOT)/rtl/rv32e_pkg.v \
    $(ROOT)/rtl/bram_dp.v \
    $(ROOT)/rtl/imem_rom.v \
    $(ROOT)/rtl/mem_2r1w.v \
    $(ROOT)/rtl/alu.v \
    $(ROOT)/rtl/regfile.v \
    $(ROOT)/rtl/decoder.v \
    $(ROOT)/rtl/rv32e_core.v \
    $(ROOT)/rtl/gpio.v \
    $(ROOT)/rtl/uart.v \
    $(ROOT)/rtl/mtimer.v \
    $(ROOT)/rtl/top.v

TOPLEVEL            = top
COCOTB_TEST_MODULES = test_top
SIM_BUILD           = $(ROOT)/build/sim_cocotb_top
COMPILE_ARGS       += -I$(ROOT)/rtl -g2005 -DSIM_NO_PLL

# Pass the app name to the test (used only for diagnostics).
export APP

# oss-cad-suite's tabbypy3 excludes the user site-packages; inject it plus this
# directory so cocotb can import the test module.
USER_PY311_SITE := $(HOME)/.local/lib/python3.11/site-packages
export PYTHONPATH := $(USER_PY311_SITE):$(ROOT)/sim/cocotb_top:$(PYTHONPATH)

# Stage the firmware as the init files top.v's $readmemh expects, in the CWD
# where vvp runs. Runs at parse time so the .hex files exist before the sim
# elaborates (the $readmemh happens at simulation time 0).
$(info Building $(APP) firmware and staging init files...)
$(shell $(MAKE) -C $(ROOT) APP=$(APP) firmware >/dev/null 2>&1 \
    && cp $(ROOT)/build/firmware.hex imem_seed.hex \
    && cp $(ROOT)/build/drom.hex     drom_seed.hex)

COCOTB_MAKEFILES := $(shell python3 -c \
    "from cocotb_tools.config import makefiles_dir; print(makefiles_dir)")

include $(COCOTB_MAKEFILES)/Makefile.sim

clean::
	rm -f imem_seed.hex drom_seed.hex results.xml
	rm -rf $(SIM_BUILD) __pycache__
