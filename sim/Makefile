# Makefile para simular RV32E
# Soporta: QuestaSim (recomendado), Icarus Verilog

SIMULATOR ?= questa

BUILD_DIR = build
TEST ?= add
UVM_TEST ?= rv32e_smoke_test

# Fuentes RTL
RTL_SRCS = ../rtl/rv32e_pkg.v \
           ../rtl/bram_dp.v \
           ../rtl/imem_rom.v \
           ../rtl/mem_2r1w.v \
           ../rtl/alu.v \
           ../rtl/regfile.v \
           ../rtl/decoder.v \
           ../rtl/rv32e_core.v \
           ../rtl/gpio.v \
           ../rtl/uart.v \
           ../rtl/mtimer.v \
           ../rtl/top.v

# Fuentes UVM
UVM_SRCS = uvm/base/rv32e_base_test.sv \
           uvm/sequences/rv32e_seq_item.sv \
           uvm/sequences/rv32e_sequence_lib.sv \
           uvm/sequences/virtual/rv32e_virtual_sequencer.sv \
           uvm/sequences/virtual/rv32e_virtual_sequence_lib.sv \
           uvm/agents/rv32e_cpu_agent.sv \
           uvm/agents/rv32e_cpu_driver.sv \
           uvm/agents/rv32e_cpu_monitor.sv \
           uvm/agents/rv32e_memory_agent.sv \
           uvm/agents/rv32e_imem_model.sv \
           uvm/agents/rv32e_dmem_model.sv \
           uvm/env/rv32e_env.sv \
           uvm/scoreboard/rv32e_scoreboard.sv \
           uvm/predictor/rv32e_predictor.sv \
           uvm/coverage/rv32e_coverage.sv \
           uvm/ral/rv32e_ral_pkg.sv \
           uvm/tests/rv32e_test_lib.sv \
           uvm/assertions/rv32e_assertions.sv

# Fuentes de testbench clásico
TB_SRCS = tb_rv32e.v

# Fuentes del firmware (para tests clásicos)
FIRMWARE_SRC = ../tests/$(TEST).S

# ============================================================================
# Configuración por simulador
# ============================================================================
ifeq ($(SIMULATOR),questa)
  SIM_CMD = vsim
  COMPILE_OPTS = -64 -svinputport=scalar -debug_all
  RUN_OPTS = -c -do "run -all; exit"
  COVERAGE = -coverage
  COV_OPTS = -ucdb $(BUILD_DIR)/coverage.ucdb
  WAVES = -vcd $(BUILD_DIR)/waves.vcd
  UVM_OPTS = +incdir+$(shell which uvm 2>/dev/null | xargs dirname | xargs dirname)/src
  UVM_OPTS += -uvmhome $(shell which uvm 2>/dev/null | xargs dirname | xargs dirname)
endif

ifeq ($(SIMULATOR),iverilog)
  SIM_CMD = iverilog
  COMPILE_OPTS = -g2012
  RUN_OPTS = 
  WAVES = -vcd
  UVM_OPTS = -I$(shell which uvm 2>/dev/null | xargs dirname | xargs dirname)/src
endif

# ============================================================================
# Objetivos
# ============================================================================
.PHONY: all clean compile run coverage waves help test-smoke test-alu test-regression

all: compile run

compile:
	@echo "=== Compilando con $(SIMULATOR) ==="
	mkdir -p $(BUILD_DIR)
ifeq ($(SIMULATOR),questa)
	$(SIM_CMD) -c $(COMPILE_OPTS) $(COVERAGE) $(COV_OPTS) \
		$(RTL_SRCS) $(UVM_SRCS) $(TB_SRCS) -o $(BUILD_DIR)/sim
endif
ifeq ($(SIMULATOR),iverilog)
	$(SIM_CMD) $(COMPILE_OPTS) $(UVM_OPTS) \
		$(RTL_SRCS) $(TB_SRCS) -o $(BUILD_DIR)/sim.vvp
endif

run: compile
	@echo "=== Ejecutando $(UVM_TEST) ==="
ifeq ($(SIMULATOR),questa)
	$(SIM_CMD) $(RUN_OPTS) $(COVERAGE) $(COV_OPTS) $(WAVES) \
		$(BUILD_DIR)/sim +UVM_TEST=$(UVM_TEST)
endif
ifeq ($(SIMULATOR),iverilog)
	vvp $(BUILD_DIR)/sim.vvp $(WAVES)
endif

coverage: compile
	@echo "=== Generando coverage ==="
ifeq ($(SIMULATOR),questa)
	cover -report $(BUILD_DIR)/coverage.html $(BUILD_DIR)/coverage.ucdb
endif

waves: compile
	@echo "=== Generando waveform ==="
ifeq ($(SIMULATOR),questa)
	$(SIM_CMD) -c -do "view wave; run -all" $(WAVES) $(BUILD_DIR)/sim
endif

clean:
	rm -rf $(BUILD_DIR)

# Tests individuales con UVM
test-smoke:
	$(MAKE) run UVM_TEST=rv32e_smoke_test

test-alu:
	$(MAKE) run UVM_TEST=rv32e_alu_test

test-load-store:
	$(MAKE) run UVM_TEST=rv32e_load_store_test

test-branch:
	$(MAKE) run UVM_TEST=rv32e_branch_test

test-csr:
	$(MAKE) run UVM_TEST=rv32e_csr_test

test-random:
	$(MAKE) run UVM_TEST=rv32e_random_test

# Test clásico (sin UVM)
test-classic:
	@echo "=== Ejecutando test clásico: $(TEST) ==="
	riscv-none-elf-gcc -march=rv32e_zicsr -mabi=ilp32e \
		-nostdlib -nostartfiles \
		-I../tests -T../sw/link.ld \
		../tests/$(TEST).S -o $(BUILD_DIR)/test.elf
	python3 ../scripts/elf2hex.py $(BUILD_DIR)/test.elf $(BUILD_DIR)/firmware.hex 0x00000000 1024
	iverilog -g2005 -I../rtl -o $(BUILD_DIR)/sim.vvp $(TB_SRCS) $(RTL_SRCS)
	vvp $(BUILD_DIR)/sim.vvp

help:
	@echo "=== RV32E Simulation ==="
	@echo "Usa: make [comando] SIMULATOR=<sim> TEST=<test>"
	@echo ""
	@echo "Comandos:"
	@echo "  all              Compilar y ejecutar (default)"
	@echo "  compile          Compilar"
	@echo "  run              Ejecutar (default: rv32e_smoke_test)"
	@echo "  coverage         Generar reporte de coverage"
	@echo "  waves            Generar waveform"
	@echo "  clean            Limpiar"
	@echo ""
	@echo "Tests UVM:"
	@echo "  test-smoke       Ejecutar smoke test"
	@echo "  test-alu         Ejecutar ALU test"
	@echo "  test-load        Ejecutar load/store test"
	@echo "  test-branch      Ejecutar branch test"
	@echo "  test-csr         Ejecutar CSR test"
	@echo ""
	@echo "Tests clásicos (sin UVM):"
	@echo "  test-classic     Ejecutar test assembly (TEST=xxx)"
	@echo ""
	@echo "Ejemplos:"
	@echo "  make SIMULATOR=questa            # Ejecutar con Questa"
	@echo "  make SIMULATOR=iverilog          # Ejecutar con Icarus"
	@echo "  make test-alu                    # Ejecutar ALU test"
	@echo "  make test-classic TEST=branch    # Ejecutar test assembly"
