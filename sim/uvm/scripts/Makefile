# Makefile for RV32E UVM Testbench
# Supports: Questa, VCS, Xcelium, Icarus Verilog

# ============================================================================
# Simulator Configuration
# ============================================================================
SIMULATOR ?= questa
# SIMULATOR ?= vcs
# SIMULATOR ?= xcelium
# SIMULATOR ?= iverilog

# ============================================================================
# Paths
# ============================================================================
UVM_HOME ?= $(UVM_HOME)
RISCV_TOOLCHAIN ?= riscv-none-elf-
RTL_DIR ?= ../..
UVM_DIR ?= .
BUILD_DIR ?= build

# ============================================================================
# Source Files
# ============================================================================
RTL_SRCS = $(RTL_DIR)/rtl/rv32e_pkg.v \
           $(RTL_DIR)/rtl/bram_dp.v \
           $(RTL_DIR)/rtl/imem_rom.v \
           $(RTL_DIR)/rtl/mem_2r1w.v \
           $(RTL_DIR)/rtl/alu.v \
           $(RTL_DIR)/rtl/regfile.v \
           $(RTL_DIR)/rtl/decoder.v \
           $(RTL_DIR)/rtl/rv32e_core.v \
           $(RTL_DIR)/rtl/gpio.v \
           $(RTL_DIR)/rtl/uart.v \
           $(RTL_DIR)/rtl/mtimer.v \
           $(RTL_DIR)/rtl/top.v

UVM_SRCS = $(UVM_DIR)/base/rv32e_base_test.sv \
           $(UVM_DIR)/sequences/rv32e_seq_item.sv \
           $(UVM_DIR)/sequences/rv32e_sequence_lib.sv \
           $(UVM_DIR)/sequences/virtual/rv32e_virtual_sequencer.sv \
           $(UVM_DIR)/sequences/virtual/rv32e_virtual_sequence_lib.sv \
           $(UVM_DIR)/agents/rv32e_cpu_agent.sv \
           $(UVM_DIR)/agents/rv32e_cpu_driver.sv \
           $(UVM_DIR)/agents/rv32e_cpu_monitor.sv \
           $(UVM_DIR)/agents/rv32e_memory_agent.sv \
           $(UVM_DIR)/agents/rv32e_imem_model.sv \
           $(UVM_DIR)/agents/rv32e_dmem_model.sv \
           $(UVM_DIR)/env/rv32e_env.sv \
           $(UVM_DIR)/scoreboard/rv32e_scoreboard.sv \
           $(UVM_DIR)/predictor/rv32e_predictor.sv \
           $(UVM_DIR)/coverage/rv32e_coverage.sv \
           $(UVM_DIR)/ral/rv32e_ral_pkg.sv \
           $(UVM_DIR)/tests/rv32e_test_lib.sv

# ============================================================================
# Compilation Flags
# ============================================================================
ifeq ($(SIMULATOR),questa)
  SIM_CMD = vsim
  COMPILE_OPTS = -64 -do "source questa_init.tcl"
  WAVES = -vcd waves.vcd
  COVERAGE = -coverage
  COVERAGE_OPTS = -ucdb coverage.ucdb
  VERIS = +incdir+$(UVM_HOME)/src
  VERIS += -sv
  VERIS += -mfcu
  VERIS += +define+UVM_REGEX_NO_DPI
  VERIS += +define+UVM_OBJECTION_TRACE
  VERIS += +define+UVM_PHASE_DEBUG
  VERIS += +define+UVM_CONFIG_DB_TRACE
  VERIS += +define+UVM_RESOURCE_DB_TRACE
  VERIS += +define+UVM_OBJECT_MERGING
  VERIS += +define+UVM_OBJECT_TRACE
  VERIS += +define+UVM_RESOURCE_TRACE
  VERIS += +define+UVM_SEQUENCER_TRACE
  VERIS += +define+UVM_REG_TRACE
  VERIS += +define+UVM_CHECKER_TRACE
  VERIS += +define+UVM_CHECKER_DEFAULT_STATE
  VERIS += +define+UVM_CHECKER_DEFAULT_VALUE
  VERIS += +define+UVM_CHECKER_DEFAULT_MODE
  VERIS += +define+UVM_CHECKER_DEFAULT_ACTION
  VERIS += +define+UVM_CHECKER_DEFAULT_REPORT
  VERIS += +define+UVM_CHECKER_DEFAULT_LEVEL
  VERIS += +define+UVM_CHECKER_DEFAULT_GROUP
  VERIS += +define+UVM_CHECKER_DEFAULT_GROUP_NAME
  VERIS += +define+UVM_CHECKER_DEFAULT_GROUP_ID
  VERIS += +define+UVM_CHECKER_DEFAULT_GROUP_MODE
  VERIS += +define+UVM_CHECKER_DEFAULT_GROUP_ACTION
  VERIS += +define+UVM_CHECKER_DEFAULT_GROUP_REPORT
  VERIS += +define+UVM_CHECKER_DEFAULT_GROUP_LEVEL
  VERIS += +define+UVM_CHECKER_DEFAULT_GROUP_NAME
  VERIS += +define+UVM_CHECKER_DEFAULT_GROUP_ID
  VERIS += +define+UVM_CHECKER_DEFAULT_GROUP_MODE
  VERIS += +define+UVM_CHECKER_DEFAULT_GROUP_ACTION
  VERIS += +define+UVM_CHECKER_DEFAULT_GROUP_REPORT
  VERIS += +define+UVM_CHECKER_DEFAULT_GROUP_LEVEL
endif

ifeq ($(SIMULATOR),vcs)
  SIM_CMD = vcs
  COMPILE_OPTS = -full64 -sverilog -debug_all -lca
  WAVES = -vcd+waves.vcd
  COVERAGE = -cm line+tgl+fsm+branch
  COVERAGE_OPTS = -cm_dir coverage
  VERIS = +incdir+$(UVM_HOME)/src
  VERIS += -uvm_home=$(UVM_HOME)
  VERIS += +define+UVM_REGEX_NO_DPI
  VERIS += +define+UVM_OBJECTION_TRACE
  VERIS += +define+UVM_CONFIG_DB_TRACE
  VERIS += +define+UVM_RESOURCE_DB_TRACE
endif

ifeq ($(SIMULATOR),xcelium)
  SIM_CMD = xrun
  COMPILE_OPTS = -64 -sv
  WAVES = -access +rwc
  COVERAGE = -coverage all
  COVERAGE_OPTS = -covtest all
  VERIS = +incdir+$(UVM_HOME)/src
  VERIS += -uvm
  VERIS += -uvmhome $(UVM_HOME)
  VERIS += +define+UVM_REGEX_NO_DPI
  VERIS += +define+UVM_OBJECTION_TRACE
  VERIS += +define+UVM_CONFIG_DB_TRACE
  VERIS += +define+UVM_RESOURCE_DB_TRACE
endif

ifeq ($(SIMULATOR),iverilog)
  SIM_CMD = iverilog
  COMPILE_OPTS = -g2012
  WAVES = -vcd
  VERIS = -I$(UVM_HOME)/src
  VERIS += -DFUNC_COVERAGE
  VERIS += -DSTRUCTURAL_COVERAGE
endif

# ============================================================================
# Targets
# ============================================================================
.PHONY: all clean compile run coverage waves help

all: compile run

# Compile
compile:
	@echo "=== Compiling RV32E UVM Testbench ==="
	@echo "Simulator: $(SIMULATOR)"
	@mkdir -p $(BUILD_DIR)
ifeq ($(SIMULATOR),questa)
	$(SIM_CMD) -c -do "compile -sv $(RTL_SRCS) $(UVM_SRCS); run -all" $(COMPILE_OPTS) $(VERIS)
endif
ifeq ($(SIMULATOR),vcs)
	$(SIM_CMD) $(RTL_SRCS) $(UVM_SRCS) $(COMPILE_OPTS) $(VERIS) -o $(BUILD_DIR)/rv32e_sim
endif
ifeq ($(SIMULATOR),xcelium)
	$(SIM_CMD) $(RTL_SRCS) $(UVM_SRCS) $(COMPILE_OPTS) $(VERIS) -elaborate $(BUILD_DIR)/rv32e_sim
endif
ifeq ($(SIMULATOR),iverilog)
	$(SIM_CMD) $(RTL_SRCS) $(UVM_SRCS) $(COMPILE_OPTS) -o $(BUILD_DIR)/rv32e_sim.vvp $(VERIS)
endif

# Run
run: compile
	@echo "=== Running RV32E UVM Testbench ==="
ifeq ($(SIMULATOR),questa)
	$(SIM_CMD) -c -do "run -all; exit" $(COVERAGE) $(COVERAGE_OPTS) $(WAVES) $(BUILD_DIR)/rv32e_sim
endif
ifeq ($(SIMULATOR),vcs)
	$(BUILD_DIR)/rv32e_sim $(COVERAGE) $(COVERAGE_OPTS) $(WAVES) +UVM_TEST=$(UVM_TEST)
endif
ifeq ($(SIMULATOR),xcelium)
	$(SIM_CMD) $(COVERAGE) $(COVERAGE_OPTS) $(WAVES) $(BUILD_DIR)/rv32e_sim
endif
ifeq ($(SIMULATOR),iverilog)
	vvp $(BUILD_DIR)/rv32e_sim.vvp $(WAVES)
endif

# Coverage
coverage: compile
	@echo "=== Generating Coverage Report ==="
ifeq ($(SIMULATOR),questa)
	cover -report $(COVERAGE_OPTS:.ucdb=) $(COVERAGE_OPTS)
endif
ifeq ($(SIMULATOR),vcs)
	urg -dir $(COVERAGE_OPTS:-cm_dir=) -report $(COVERAGE_OPTS:-cm_dir=)
endif
ifeq ($(SIMULATOR),xcelium)
	coverageReport -dir $(COVERAGE_OPTS:-covtest=) -output $(COVERAGE_OPTS:-covtest=)/coverage.html
endif

# Waves
waves: compile
	@echo "=== Generating Waveform ==="
ifeq ($(SIMULATOR),questa)
	$(SIM_CMD) -c -do "view wave; run -all" $(WAVES) $(BUILD_DIR)/rv32e_sim
endif
ifeq ($(SIMULATOR),vcs)
	$(BUILD_DIR)/rv32e_sim $(WAVES)
endif
ifeq ($(SIMULATOR),xcelium)
	$(SIM_CMD) $(WAVES) $(BUILD_DIR)/rv32e_sim
endif

# Clean
clean:
	@echo "=== Cleaning ==="
	rm -rf $(BUILD_DIR)
	rm -rf coverage
	rm -rf *.vcd *.fsdb *.ucdb *.daidir
	rm -rf simv* csrc**.daidir

# Help
help:
	@echo "=== RV32E UVM Testbench Makefile ==="
	@echo ""
	@echo "Usage: make [target] [options]"
	@echo ""
	@echo "Targets:"
	@echo "  all          - Compile and run (default)"
	@echo "  compile      - Compile the testbench"
	@echo "  run          - Run the testbench (requires compile)"
	@echo "  coverage     - Generate coverage report"
	@echo "  waves        - Generate waveform"
	@echo "  clean        - Clean build artifacts"
	@echo "  help         - Show this help"
	@echo ""
	@echo "Options:"
	@echo "  SIMULATOR=<sim>  - Simulator: questa, vcs, xcelium, iverilog"
	@echo "  UVM_TEST=<test>  - Test name to run"
	@echo "  UVM_TESTCASE=<n> - Test case number"
	@echo ""
	@echo "Examples:"
	@echo "  make                     - Run with Questa (default)"
	@echo "  make SIMULATOR=vcs       - Run with VCS"
	@echo "  make run UVM_TEST=alu_test - Run ALU test"
	@echo "  make waves SIMULATOR=xcelium - Generate waveform with Xcelium"

# Run specific test
test-alu:
	$(MAKE) run UVM_TEST=rv32e_alu_test

test-load-store:
	$(MAKE) run UVM_TEST=rv32e_load_store_test

test-branch:
	$(MAKE) run UVM_TEST=rv32e_branch_test

test-csr:
	$(MAKE) run UVM_TEST=rv32e_csr_test

test-stress:
	$(MAKE) run UVM_TEST=rv32e_stress_test

test-integration:
	$(MAKE) run UVM_TEST=rv32e_integration_test

test-random:
	$(MAKE) run UVM_TEST=rv32e_random_test

test-smoke:
	$(MAKE) run UVM_TEST=rv32e_smoke_test

test-error:
	$(MAKE) run UVM_TEST=rv32e_error_test

# Regression
regression: compile
	@echo "=== Running Regression Suite ==="
	$(MAKE) test-alu
	$(MAKE) test-load-store
	$(MAKE) test-branch
	$(MAKE) test-csr
	$(MAKE) test-stress
	$(MAKE) test-integration
	$(MAKE) test-random
	$(MAKE) test-smoke
	$(MAKE) test-error
	@echo "=== Regression Complete ==="
