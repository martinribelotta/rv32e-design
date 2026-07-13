# RV32E Simulation Guide

## Quick Start

### With QuestaSim (Recommended)

```bash
# Setup Questa (one time)
cd sim
source setup_quartus.sh

# Run test with Questa
make SIMULATOR=questa
make SIMULATOR=questa UVM_TEST=rv32e_alu_test
make SIMULATOR=questa UVM_TEST=rv32e_branch_test

# Generate waveform
make SIMULATOR=questa waves

# Generate coverage
make SIMULATOR=questa coverage
```

### With Icarus Verilog (Free)

```bash
# Run classic test (without UVM)
make SIMULATOR=iverilog

# With waveform
make SIMULATOR=iverilog waves
```

## Tests Disponibles

### UVM Tests (Complete)

| Test | Description |
|------|-------------|
| `rv32e_smoke_test` | Basic functionality test |
| `rv32e_alu_test` | ALU operations (ADD, SUB, AND, OR, XOR, etc.) |
| `rv32e_load_store_test` | Memory operations (LB, LH, LW, SB, SH, SW) |
| `rv32e_branch_test` | Conditional branches (BEQ, BNE, BLT, BGE, etc.) |
| `rv32e_csr_test` | Control and status registers |
| `rv32e_random_test` | Random instructions with constraints |
| `rv32e_stress_test` | High-volume instruction testing |
| `rv32e_integration_test` | Complete system test |

### Tests Clásicos (Assembly)

```bash
make SIMULATOR=iverilog TEST=add
make SIMULATOR=iverilog TEST=branch
make SIMULATOR=iverilog TEST=load_store
# etc...
```

## Testbench Architecture

```
sim/
├── Makefile                    # Main build script
├── setup_quartus.sh           # QuestaSim setup script
├── tb_rv32e.v                 # Classic testbench
├── rtl/                       # RTL sources
│   └── rv32e_core.v
└── uvm/                       # UVM testbench (complete)
    ├── base/                  # Base classes
    ├── env/                   # Environment
    ├── agents/                # CPU, Memory agents
    ├── scoreboard/            # Result checking
    ├── predictor/             # Reference model
    ├── sequences/             # Sequences
    ├── coverage/              # Functional coverage
    ├── ral/                   # UVM RAL model
    ├── tests/                 # 10+ test classes
    ├── assertions/            # SVA assertions
    └── docs/                  # Documentation
```

## QuestaSim Usage

### Basic Commands

```bash
# Compile
vsim -64 -sv -debug_all rtl/*.v uvm/*.v tb_rv32e.v -o sim

# Run
vsim sim
run -all

# Generate waveform
view wave
add wave -r sim/*

# Generate coverage
coverage save -onexit -ucdb coverage.ucdb
```

### Useful Questa Commands

| Command | Description |
|---------|-------------|
| `run -all` | Run until completion |
| `run 100ns` | Run for 100 nanoseconds |
| `view wave` | View waveform |
| `coverage report` | Coverage report |
| `quit` | Exit |

## Troubleshooting

### "vsim not found"
Install QuestaSim or use Icarus:
```bash
make SIMULATOR=iverilog
```

### "UVM not found"
```bash
# Configure UVM
export UVM_HOME=$QUESTA_HOME/verilog_src/uvm-1.2
```

### Compilation errors
```bash
# Verify all paths are correct
ls -la ../rtl/
ls -la uvm/
```

## Intel Quartus Integration

If using Intel Quartus:

```bash
# Setup Questa from Quartus
source /opt/intelFPGA/setup_quartus.sh

# Compile and simulate
make SIMULATOR=questa
```

## Generated Files

| File | Description |
|---------|-------------|
| `sim/` | Simulation executable |
| `build/waves.vcd` | Waveform for viewing with GTKWave |
| `build/coverage.ucdb` | Coverage database |

## Next Steps

1. [ ] Compile firmware for tests
2. [ ] Run full regression suite
3. [ ] Open waveform with GTKWave
4. [ ] Analyze coverage report
