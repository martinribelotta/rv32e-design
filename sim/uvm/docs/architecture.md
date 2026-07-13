# RV32E UVM Testbench Architecture

## Overview

This document describes the architecture of the UVM testbench for the RV32E RISC-V core.

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Test Layer                              │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │  test    │  │  test    │  │  test    │  │  test    │   │
│  │  smoke   │  │   alu    │  │  load    │  │  branch  │   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                   Virtual Sequence Layer                    │
│  ┌─────────────────────────────────────────────────────┐   │
│  │          rv32e_virtual_sequencer                    │   │
│  │  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐       │   │
│  │  │  cpu   │ │ imem   │ │ dmem   │ │  reg   │       │   │
│  │  │sequencer││sequencer││sequencer││sequencer│       │   │
│  │  └────────┘ └────────┘ └────────┘ └────────┘       │   │
│  └─────────────────────────────────────────────────────┘   │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                  Environment Layer                          │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                 rv32e_env                           │   │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐    │   │
│  │  │ cpu_agent  │  │mem_agent   │  │peri_agent  │    │   │
│  │  │ ┌────────┐ │  │ ┌────────┐ │  │ ┌────────┐ │    │   │
│  │  │ │driver  │ │  │ │driver  │ │  │ │monitor │ │    │   │
│  │  │ │monitor │ │  │ │monitor │ │  │ └────────┘ │    │   │
│  │  │ │seqr    │ │  │ │models  │ │  └────────────┘    │   │
│  │  │ └────────┘ │  │ └────────┘ │                     │   │
│  │  └────────────┘  └────────────┘                     │   │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐    │   │
│  │  │scoreboard  │  │ predictor  │  │ coverage   │    │   │
│  │  │            │  │            │  │            │    │   │
│  │  └────────────┘  └────────────┘  └────────────┘    │   │
│  └─────────────────────────────────────────────────────┘   │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                   DUT Layer                                 │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              rv32e_core (DUT)                       │   │
│  │  ┌──────────────────────────────────────────────┐  │   │
│  │  │  IF  │ ID/EX │ MEM/WB │ Pipeline Registers │  │   │
│  │  │  pc  │decode │ dmem   │ Registers          │  │   │
│  │  │fetch │ regfile│ access │ IF/ID, EX/MEM,    │  │   │
│  │  │      │  +ALU │        │ MEM/WB             │  │   │
│  │  └──────────────────────────────────────────────┘  │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Component Descriptions

### 1. Test Layer

**Purpose**: Define specific test scenarios

**Components**:
- `rv32e_base_test` - Base class for all tests
- `rv32e_smoke_test` - Basic functionality
- `rv32e_alu_test` - ALU operations
- `rv32e_load_store_test` - Memory operations
- `rv32e_branch_test` - Control flow
- `rv32e_csr_test` - CSR operations
- `rv32e_stress_test` - High-volume operations
- `rv32e_integration_test` - Full system test
- `rv32e_random_test` - Random coverage
- `rv32e_error_test` - Edge cases

### 2. Virtual Sequence Layer

**Purpose**: Coordinate multiple agents

**Components**:
- `rv32e_virtual_sequencer` - Coordinates sequencers
- `rv32e_virtual_sequence` - Base for virtual sequences
- `rv32e_random_cpu_vseq` - Random CPU operations
- `rv32e_alu_mem_vseq` - ALU + memory coordination
- `rv32e_csr_branch_vseq` - CSR + branch coordination
- `rv32e_stress_vseq` - Stress test coordination
- `rv32e_integration_vseq` - Full system test

### 3. Environment Layer

**Purpose**: Instantiate and connect all components

**Components**:

#### rv32e_env
- Creates and configures all agents
- Connects analysis ports to FIFOs
- Manages virtual interfaces
- Configures coverage and assertions

#### cpu_agent
- **driver**: Drives instructions to DUT
- **monitor**: Monitors pipeline stages
- **sequencer**: Executes sequences

#### memory_agent
- **driver**: Drives memory operations
- **monitor**: Monitors memory accesses
- **imem_model**: Instruction memory model
- **dmem_model**: Data memory model

#### peripheral_agent
- **monitor**: Monitors UART, Timer, GPIO

#### scoreboard
- Checks expected vs actual results
- Tracks statistics
- Reports pass/fail

#### predictor
- Reference model for CPU behavior
- Calculates expected results
- Maintains CPU state

#### coverage
- Functional coverage groups
- Coverage reporting

### 4. DUT Layer

**rv32e_core**
- 3-stage pipeline (IF, ID/EX, MEM/WB)
- RV32E instruction set
- CSR registers
- Interrupt handling

## Data Flow

### Instruction Path
```
Test → Virtual Sequence → Virtual Sequencer → CPU Sequencer
     → CPU Driver → DUT (IF stage)
     → CPU Monitor → Scoreboard
```

### Memory Path
```
CPU → Memory Agent → Memory Model → Scoreboard
```

### Coverage Path
```
CPU Monitor → Coverage Collector
Memory Monitor → Coverage Collector
```

## Class Hierarchy

```
uvm_test
└── rv32e_base_test
    ├── rv32e_smoke_test
    ├── rv32e_alu_test
    ├── rv32e_load_store_test
    ├── rv32e_branch_test
    ├── rv32e_csr_test
    ├── rv32e_stress_test
    ├── rv32e_integration_test
    ├── rv32e_random_test
    └── rv32e_error_test

uvm_sequencer
└── rv32e_virtual_sequencer

uvm_sequence
└── rv32e_virtual_sequence
    ├── rv32e_random_cpu_vseq
    ├── rv32e_alu_mem_vseq
    ├── rv32e_csr_branch_vseq
    ├── rv32e_stress_vseq
    └── rv32e_integration_vseq

uvm_agent
├── rv32e_cpu_agent
└── rv32e_memory_agent

uvm_driver
├── rv32e_cpu_driver
└── rv32e_memory_driver

uvm_monitor
├── rv32e_cpu_monitor
└── rv32e_memory_monitor

uvm_scoreboard
└── rv32e_scoreboard

uvm_component
├── rv32e_predictor
└── rv32e_coverage

uvm_env
└── rv32e_env
```

## Interface Definitions

### rv32e_if (Virtual Interface)
```systemverilog
interface rv32e_if (
    input clk,
    input rst_n,
    
    // CPU interface
    output reg [31:0] pc,
    input  reg [31:0] imem_rdata,
    output reg [31:0] dmem_addr,
    output reg [31:0] dmem_wdata,
    output reg [3:0]  dmem_we,
    input  reg [31:0] dmem_rdata,
    
    // Decoder output
    output reg [6:0]  opcode,
    output reg [3:0]  rs1,
    output reg [3:0]  rs2,
    output reg [3:0]  rd,
    output reg [2:0]  funct3,
    output reg [6:0]  funct7,
    output reg [31:0] imm_i,
    output reg [31:0] imm_s,
    output reg [31:0] imm_b,
    output reg [31:0] imm_u,
    output reg [31:0] imm_j,
    output reg [3:0]  alu_op,
    output reg        reg_write,
    output reg        mem_read,
    output reg        mem_write,
    
    // Pipeline stages
    output reg [31:0] if_id_pc,
    output reg [31:0] if_id_instr,
    output reg [31:0] ex_mem_result,
    output reg [31:0] mem_wb_result,
    
    // CSR
    output reg [11:0] csr_addr,
    output reg [2:0]  csr_cmd,
    output reg        csr_imm,
    
    // Branch
    output reg        branch_taken,
    output reg [2:0]  branch_cond
);
```

## Configuration

### Using uvm_config_db
```systemverilog
// Set configuration
uvm_config_db#(int)::set(this, "m_env", "max_cycles", 100000);
uvm_config_db#(bit)::set(this, "m_env", "enable_coverage", 1);

// Get configuration
void'(uvm_config_db#(int)::get(this, "", "max_cycles", max_cycles));
```

### Factory Overrides
```systemverilog
// Override test
rv32e_alu_test::type_id::set_type_override(rv32e_custom_alu_test::get_type());

// Override component
rv32e_scoreboard::type_id::set_type_override(rv32e_custom_scoreboard::get_type());
```

## Thread Model

```
run_phase()
├── cpu_agent.run_phase()
│   ├── driver.run_phase() (forked)
│   └── monitor.run_phase() (forked)
├── memory_agent.run_phase()
│   ├── driver.run_phase() (forked)
│   └── monitor.run_phase() (forked)
├── scoreboard.run_phase()
├── predictor.run_phase()
└── coverage.run_phase()
```

## Best Practices Followed

1. **Separation of Concerns**: Each layer has a specific responsibility
2. **Reusability**: Components can be reused across tests
3. **Configurability**: uvm_config_db for runtime configuration
4. **Extensibility**: Easy to add new tests and components
5. **Coverage-Driven**: Functional coverage built into environment
6. **Automation**: Makefile for build/run/coverage
7. **Documentation**: Complete documentation for all components

## Future Enhancements

1. Add AXI interface agent
2. Add cache model
3. Add pipeline prediction model
4. Add performance counters
5. Add power estimation
6. Add formal verification support
