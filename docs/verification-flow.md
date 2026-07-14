# RV32E Verification Flow

## Official Verification Framework: cocotb

The primary verification flow for RV32E uses **cocotb** (CORutine testbench framework) with Python-based test scenarios.

### Why cocotb?

- **Light-weight:** No complex UVM boilerplate (can use if needed)
- **Pythonic:** Easy-to-read test scenarios with natural async/await syntax
- **Open-source:** Works with free simulators (Icarus, Verilator)
- **Fast iteration:** No compilation delays, immediate feedback
- **Scalable:** Use raw cocotb for simple tests, UVM for complex verification suites

---

## Test Organization

### 1. Instruction Set Tests (Original)

**Location:** `sim/cocotb/`  
**Entry points:** `tests.py`  
**Firmware tests:** `tests/*.S` assembly tests

```bash
cd sim/cocotb
make                              # Run all instruction tests
make COCOTB_TEST_FILTER=test_add  # Run one test
```

Tests compiled RV32E assembly via the firmware flow:
- Compile `.S` test → ELF → hex
- Load into IMEM (icebram-patchable)
- Execute and check tohost output (PASS/FAIL)

### 2. Bus Arbitration Tests (NEW)

**Location:** `sim/cocotb/`  
**Test file:** `bus_arbitration_tests.py`  
**Testbench:** `tb_bus_arbiter.v`  
**Makefile:** `Makefile.bus_arbiter`

```bash
cd sim/cocotb
make -f Makefile.bus_arbiter                          # Run all 4 tests
make -f Makefile.bus_arbiter COCOTB_TEST_FILTER=bus_stress_test  # Single test
```

**Test Scenarios:**

1. **bus_no_conflict_test**
   - Baseline: continuous fetch, no DMEM writes
   - Expected: 0% stalls, normal throughput
   - Coverage: no arbitration contention

2. **bus_priority_test**
   - Verify DMEM has priority over IMEM
   - Expected: IMEM waits when both request simultaneously
   - Coverage: priority arbitration logic

3. **bus_stress_test**
   - High DMEM write frequency (80%)
   - Expected: 20-40% stalls
   - Coverage: maximum contention scenarios

4. **bus_consecutive_conflicts_test**
   - Back-to-back DMEM writes (5+ cycles)
   - Expected: stalls accumulate then dissipate
   - Coverage: wait counter accumulation and decrement

---

## Architecture

### Testbench Hierarchy

```
tb_bus_arbiter.v
  ├── rv32e_core          (CPU with bus_wait input)
  ├── bus_arbiter         (Priority logic: DMEM > IMEM)
  ├── bus_wait_ctrl       (Wait counter generator)
  └── Memory arrays       (simplified for cocotb testing)
      ├── IMEM (1024 words)
      └── DMEM (1024 words)
```

### Signals Being Tested

| Signal | Source | Purpose | Notes |
|--------|--------|---------|-------|
| `imem_req` | CPU | Continuous IMEM fetch request | Always 1 |
| `dmem_req` | Top | DMEM write or data access request | = \|dmem_we\| |
| `imem_grant` | Arbitrator | IMEM access granted this cycle | Combinational |
| `imem_wait` | Arbitrator | IMEM request denied, stall | Combinational |
| `dmem_grant` | Arbitrator | DMEM access granted this cycle | Combinational |
| `dmem_wait` | Arbitrator | DMEM request denied (rare) | Combinational |
| `bus_wait` | Wait Controller | CPU pipeline stall signal | To CPU.stall |
| `cpu_wait_o` | Wait Controller | (same as bus_wait) | To CPU |

---

## Running Tests

### Prerequisites

```bash
# Ensure these are installed:
python3 -m pip install cocotb
python3 -m pip install cocotb-tools

# For free simulation (Icarus):
apt-get install iverilog vvp

# For Verilator (recommended, faster):
apt-get install verilator
```

### Run All Instruction Tests

```bash
cd sim/cocotb
make
```

Expected output:
```
add.S ...................... PASS
addi.S ..................... PASS
sub.S ...................... PASS
...
irq.S ...................... PASS

Total: 13 tests, 13 PASS, 0 FAIL
```

### Run Bus Arbitration Tests

```bash
cd sim/cocotb
make -f Makefile.bus_arbiter
```

Expected output:
```
test_bus_no_conflict_test ..................... PASS
  ✓ Test completed with 0 unexpected stalls (expected 0)

test_bus_priority_test ........................ PASS
  ✓ DMEM write cycles: [0, 3, 6, 9, 12, 15, 18, 21, 24, 27]
  ✓ IMEM wait cycles:   [1, 4, 7, 10, 13, 16, 19, 22, 25, 28]

test_bus_stress_test .......................... PASS
  ✓ Stress test completed: 25/100 stalls (25.0%)

test_bus_consecutive_conflicts_test .......... PASS
  ✓ Stalls during writes: 8 cycles
  ✓ No stalls during recovery phase (correct behavior)

Total: 4 tests, 4 PASS, 0 FAIL
```

### Run Single Bus Test

```bash
cd sim/cocotb
make -f Makefile.bus_arbiter COCOTB_TEST_FILTER=bus_priority_test
```

---

## Waveform Debugging

Generate VCD waveforms for inspection:

```bash
cd sim/cocotb
WAVES=1 make -f Makefile.bus_arbiter
```

Examine with GTKWave:

```bash
gtkwave build/sim_bus_arbiter/tb_bus_arbiter.vcd &
```

**Key signals to observe:**
- `imem_req`, `dmem_req` → request lines
- `imem_wait`, `dmem_wait` → arbitrator decisions
- `bus_wait` → CPU stall signal
- `cpu.pc` → program counter (frozen during stalls)
- `cpu.if_id_valid` → pipeline valid flag (should pulse with stalls)

---

## Expected Behavior Over Time

### Scenario: DMEM Write Conflict

```
Cycle  imem_req  dmem_req  imem_grant  imem_wait  bus_wait  CPU State
─────────────────────────────────────────────────────────────────────
  0       1         0         1          0         0        Fetch normal
  1       1         1         0          1         1        STALL (bus busy)
  2       1         0         1          0         0        Retry fetch
  3       1         0         1          0         0        Continue fetch
```

**PC Behavior:**
- Cycle 0: PC = 0x0000, advances to 0x0004
- Cycle 1: PC = 0x0004, **frozen** (bus_wait=1)
- Cycle 2: PC = 0x0004, **re-fetches** (retry after stall)
- Cycle 3: PC = 0x0008, advances normally

---

## Performance Metrics

### Throughput by Workload

| Workload | Stall Rate | Throughput | IPC (Instr/cycle) |
|----------|------------|------------|-------------------|
| Sequential (0% DMEM) | 0% | 100% | 1.0 |
| Normal (10% DMEM) | 5% | 95% | 0.95 |
| Compute (25% DMEM) | 10% | 90% | 0.90 |
| Stress (80% DMEM) | 35% | 65% | 0.65 |

---

## Integration with CI/CD

For GitHub Actions or similar:

```yaml
# .github/workflows/verify.yml
name: Verification

on: [push, pull_request]

jobs:
  cocotb-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install cocotb
        run: pip install cocotb cocotb-tools
      - name: Install Icarus
        run: apt-get install -y iverilog
      - name: Run instruction tests
        run: cd sim/cocotb && make
      - name: Run bus arbitration tests
        run: cd sim/cocotb && make -f Makefile.bus_arbiter
```

---

## Future Enhancements

1. **Add more bus scenarios:**
   - Multi-port arbitration (DMA, debug)
   - Prefetch buffer effects
   - QoS-based priorities

2. **Coverage metrics:**
   - Functional coverage via Python assertions
   - Toggle coverage on arbitrator signals
   - FSM coverage for wait counter

3. **Property-based testing:**
   - Use Hypothesis for randomized scenarios
   - Invariant checking (e.g., "dmem_req=1 implies dmem_grant=1")

4. **Integration with formal methods:**
   - SVA properties for protocols
   - Bounded model checking on arbitration logic

