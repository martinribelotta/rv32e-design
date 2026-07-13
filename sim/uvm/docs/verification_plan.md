# RV32E UVM Verification Plan

## Overview

This document describes the verification plan for the RV32E RISC-V core implemented in Verilog.

### Goals

- Verify complete RV32E instruction set compliance
- Verify CSR register access and interrupt handling
- Verify memory operations (load/store)
- Verify control flow (branches, jumps)
- Verify pipeline behavior and hazards
- Achieve 100% coverage closure

### Scope

- RV32E base instruction set
- Machine mode CSR registers
- Memory interface (IMEM/DMEM)
- Interrupt handling (MEI, MTIP)
- Pipeline stages (IF, ID/EX, MEM/WB)

## Verification Approach

### 1. Test Types

| Test Type | Description | Coverage Goal |
|-----------|-------------|---------------|
| Smoke Test | Basic functionality check | 10% |
| ALU Test | Integer arithmetic and logic | 20% |
| Load/Store Test | Memory operations | 15% |
| Branch Test | Control flow transfers | 15% |
| CSR Test | Register access and interrupts | 15% |
| Stress Test | High-volume operations | 5% |
| Random Test | Constrained-random coverage | 15% |
| Error Test | Edge cases and error handling | 5% |

### 2. Coverage Goals

| Coverage Type | Target | Method |
|-------------|--------|--------|
| Instruction Coverage | 100% | Directed + Random |
| Branch Coverage | 100% | All branch conditions |
| Statement Coverage | 100% | Code review + Tests |
| FSM Coverage | 100% | Pipeline state transitions |
| Toggle Coverage | 95% | Random + Stress |
| Functional Coverage | 100% | Coverage groups |

### 3. Test Categories

#### Directed Tests
- Each instruction type tested individually
- Known good sequences verified
- Exception cases covered

#### Random Tests
- Constrained random instruction generation
- Instruction mix optimization
- Register file coverage

#### Stress Tests
- High instruction throughput
- Memory pressure
- Pipeline saturation

#### Edge Case Tests
- Zero register usage
- All-ones values
- Boundary addresses
- Invalid CSRs

## Environment Architecture

```
rv32e_env
├── cpu_agent
│   ├── driver    (drives instructions)
│   ├── monitor   (monitors pipeline)
│   └── sequencer (sequence execution)
├── memory_agent
│   ├── driver    (memory operations)
│   ├── monitor   (memory access monitor)
│   └── imem/dmem models
├── peripheral_agent
│   └── UART/Timer monitoring
├── scoreboard    (result checking)
├── predictor     (reference model)
└── coverage      (functional coverage)
```

## Testbench Components

### 1. Sequence Items

**rv32e_seq_item** - Models a single instruction with:
- All instruction fields (opcode, rs1, rs2, rd, funct3, funct7)
- Immediate values (I, S, B, U, J types)
- ALU operation
- Memory operation
- Branch condition
- CSR operation
- Constraints for randomization

### 2. Agents

#### CPU Agent
- **Driver**: Sends instructions to the CPU
- **Monitor**: Observes pipeline stages
- **Sequencer**: Executes sequences

#### Memory Agent
- **Driver**: Initiates memory operations
- **Monitor**: Observes memory accesses
- **Models**: IMEM/DMEM with $readmemh compatibility

#### Peripheral Agent
- **Monitor**: UART, Timer, GPIO operations

### 3. Scoreboard

- Compares expected vs actual results
- Tracks instruction execution
- Reports pass/fail status

### 4. Predictor

- Models CPU behavior
- Calculates expected results
- Maintains CPU state

### 5. Coverage

- Opcode coverage
- Pipeline stage coverage
- Register usage coverage
- CSR operation coverage
- Branch condition coverage
- Memory operation coverage

## Test Cases

### ALU Tests
- ADD, SUB, SLL, SLT, SLTU
- XOR, SRL, SRA, OR, AND
- Immediate variants (ADDI, SLLI, etc.)

### Load/Store Tests
- LB, LH, LW, LBU, LHU
- SB, SH, SW
- Byte-enable operations

### Branch Tests
- BEQ, BNE, BLT, BGE, BLTU, BGEU
- Taken/not-taken scenarios

### CSR Tests
- CSRRW, CSRRS, CSRRC
- MSTATUS, MIE, MIP, MTVEC
- MEPC, MCAUSE
- Interrupt handling

### Stress Tests
- 1000+ back-to-back ALU operations
- Mixed load/store stress
- Pipeline saturation

## Coverage Closure Strategy

### Phase 1: Basic Coverage (Week 1)
- [ ] Opcode coverage: 50%
- [ ] Instruction coverage: 60%
- [ ] Register coverage: 70%

### Phase 2: Enhanced Coverage (Week 2)
- [ ] Opcode coverage: 80%
- [ ] Instruction coverage: 90%
- [ ] Branch coverage: 80%

### Phase 3: Full Coverage (Week 3)
- [ ] Opcode coverage: 100%
- [ ] Instruction coverage: 100%
- [ ] Branch coverage: 100%
- [ ] Functional coverage: 100%

## Automation

### Makefile Targets
```bash
make compile       # Compile testbench
make run           # Run tests
make coverage      # Generate coverage report
make waves         # Generate waveform
make clean         # Clean build artifacts
make regression    # Run all tests
```

### CI/CD Integration
- GitHub Actions for automated testing
- Coverage reporting
- Regression tracking

## Results Reporting

### Test Output
```
=== UVM Report Summary ===
Errors: 0
Warnings: 0
Test Name: rv32e_alu_test
```

### Coverage Report
```
Opcode Coverage: 100.00%
Pipeline Coverage: 95.50%
Register Coverage: 100.00%
CSR Coverage: 98.00%
Branch Coverage: 100.00%
Memory Coverage: 97.00%
```

## Known Limitations

1. No misaligned access traps implemented
2. No hardware multiply/divide
3. Simplified mstatus (no MPIE/MPP)

## Future Enhancements

1. Add AXI interface
2. Add cache model
3. Add pipeline prediction model
4. Add speculative execution model
5. Add performance counters

## References

- RISC-V Instruction Set Manual, Volume I: Unprivileged ISA
- RISC-V Instruction Set Manual, Volume II: Privileged ISA
- UVM User Guide
- RV32E Core Specification
