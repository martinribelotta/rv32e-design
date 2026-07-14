# cocotb + pyuvm simulation for rv32e_core
#
# Usage:
#   make                                  — run all core tests
#   make COCOTB_TEST_FILTER=test_add      — run one test (regex)
#   make COCOTB_TEST_FILTER='test_add|test_branch'  — multiple
#   make test_bus_arbiter                 — run bus arbitration tests only
#
# Bus Arbitration Tests:
#   make test_bus_arbiter                 — Run all 4 bus arbitration tests
#   make test_bus_arbiter COCOTB_TEST_FILTER=bus_priority_test  — single test

SIM           ?= icarus
TOPLEVEL_LANG  = verilog
ROOT          := $(abspath ../..)

# Default: test rv32e_core instruction tests
VERILOG_SOURCES = \
    $(ROOT)/rtl/rv32e_pkg.v \
    $(ROOT)/rtl/bram_dp.v \
    $(ROOT)/rtl/alu.v \
    $(ROOT)/rtl/regfile.v \
    $(ROOT)/rtl/decoder.v \
    $(ROOT)/rtl/rv32e_core.v \
    $(ROOT)/rtl/bus_arbiter.v \
    $(ROOT)/rtl/bus_wait_ctrl.v \
    $(ROOT)/rtl/mem_2r1w.v \
    $(ROOT)/rtl/imem_rom.v

COCOTB_TEST_MODULES = tests
TOPLEVEL            = rv32e_core
SIM_BUILD           = $(ROOT)/build/sim_cocotb

COMPILE_ARGS += -I$(ROOT)/rtl -g2005

# oss-cad-suite's tabbypy3 has a private sys.path that excludes the user
# site-packages where pyuvm was installed.  Inject the user path so vvp/cocotb
# can find pyuvm and our local Python modules.
USER_PY311_SITE := $(HOME)/.local/lib/python3.11/site-packages
export PYTHONPATH := $(USER_PY311_SITE):$(ROOT)/sim/cocotb:$(PYTHONPATH)

COCOTB_MAKEFILES := $(shell python3 -c \
    "from cocotb_tools.config import makefiles_dir; print(makefiles_dir)")

include $(COCOTB_MAKEFILES)/Makefile.sim

