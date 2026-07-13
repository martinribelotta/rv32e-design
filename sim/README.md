# RV32E Simulation Guide

## Quick Start

### Con QuestaSim (Recomendado)

```bash
# Configurar Questa (una vez)
cd sim
source setup_quartus.sh

# Ejecutar test con Questa
make SIMULATOR=questa
make SIMULATOR=questa UVM_TEST=rv32e_alu_test
make SIMULATOR=questa UVM_TEST=rv32e_branch_test

# Generar waveform
make SIMULATOR=questa waves

# Generar coverage
make SIMULATOR=questa coverage
```

### Con Icarus Verilog (Gratuito)

```bash
# Ejecutar test clásico (sin UVM)
make SIMULATOR=iverilog

# Con waveform
make SIMULATOR=iverilog waves
```

## Tests Disponibles

### Tests UVM (Completos)

| Test | Descripción |
|------|-------------|
| `rv32e_smoke_test` | Prueba básica de funcionamiento |
| `rv32e_alu_test` | Operaciones ALU (ADD, SUB, AND, OR, XOR, etc.) |
| `rv32e_load_store_test` | Operaciones de memoria (LB, LH, LW, SB, SH, SW) |
| `rv32e_branch_test` | Saltos condicionales (BEQ, BNE, BLT, BGE, etc.) |
| `rv32e_csr_test` | Registros de control y estado |
| `rv32e_random_test` | Instrucciones aleatorias con restricciones |
| `rv32e_stress_test` | Alta volumetría de instrucciones |
| `rv32e_integration_test` | Test completo del sistema |

### Tests Clásicos (Assembly)

```bash
make SIMULATOR=iverilog TEST=add
make SIMULATOR=iverilog TEST=branch
make SIMULATOR=iverilog TEST=load_store
# etc...
```

## Arquitectura del Testbench

```
sim/
├── Makefile                    # Script de build principal
├── setup_quartus.sh           # Setup para QuestaSim
├── tb_rv32e.v                 # Testbench clásico
├── rtl/                       # Fuentes RTL
│   └── rv32e_core.v
└── uvm/                       # Testbench UVM (completo)
    ├── base/                  # Clases base
    ├── env/                   # Environment
    ├── agents/                # CPU, Memory agents
    ├── scoreboard/            # Verificación
    ├── predictor/             # Modelo de referencia
    ├── sequences/             # Secuencias
    ├── coverage/              # Cobertura funcional
    ├── ral/                   # UVM RAL model
    ├── tests/                 # 10+ test classes
    ├── assertions/            # SVA assertions
    └── docs/                  # Documentación
```

## Uso de QuestaSim

### Comandos Básicos

```bash
# Compilar
vsim -64 -sv -debug_all rtl/*.v uvm/*.v tb_rv32e.v -o sim

# Ejecutar
vsim sim
run -all

# Generar waveform
view wave
add wave -r sim/*

# Generar coverage
coverage save -onexit -ucdb coverage.ucdb
```

### Comandos Útiles en Questa

| Comando | Descripción |
|---------|-------------|
| `run -all` | Ejecutar hasta terminar |
| `run 100ns` | Ejecutar 100 nanosegundos |
| `view wave` | Ver waveform |
| `coverage report` | Reporte de coverage |
| `quit` | Salir |

## Solución de Problemas

### "vsim not found"
Instala QuestaSim o usa Icarus:
```bash
make SIMULATOR=iverilog
```

### "UVM not found"
```bash
# Configurar UVM
export UVM_HOME=$QUESTA_HOME/verilog_src/uvm-1.2
```

### Errores de compilación
```bash
# Verifica que todos los paths sean correctos
ls -la ../rtl/
ls -la uvm/
```

## Integration con Intel Quartus

Si usas Intel Quartus:

```bash
# Setup Questa desde Quartus
source /opt/intelFPGA/setup_quartus.sh

# Compilar y simular
make SIMULATOR=questa
```

## Archivos Generados

| Archivo | Descripción |
|---------|-------------|
| `sim/` | Executable de simulación |
| `build/waves.vcd` | Waveform para ver con GTKWave |
| `build/coverage.ucdb` | Database de coverage |

## Próximos Pasos

1. [ ] Compilar firmware para los tests
2. [ ] Correr regression suite completa
3. [ ] Abrir waveform con GTKWave
4. [ ] Analizar coverage report
