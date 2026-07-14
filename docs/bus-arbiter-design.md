# Bus Arbiter with Wait States Design

## Overview

The RV32E core requires simultaneous access to IMEM (instruction fetch) and DMEM (data read/write) through a unified 2R1W memory block. When both ports request access in the same cycle, a **bus contention** occurs, requiring **wait state insertion** to serialize memory access.

## Architecture

### 1. Bus Arbitrator (`bus_arbiter.v`)

**Purpose:** Arbitrates simultaneous IMEM and DMEM requests.

**Arbitration Policy:** Priority-based
- DMEM (data) has **HIGH priority** (prevents data hazards)
- IMEM (instruction) has **LOW priority** (can tolerate stalls)

**Logic:**
```verilog
if (dmem_req && imem_req) {
    // Conflict: grant DMEM, stall IMEM
    dmem_grant = 1'b1;
    imem_grant = 1'b0;
    imem_wait = 1'b1;
} else if (dmem_req) {
    dmem_grant = 1'b1;
    imem_grant = 1'b0;
} else if (imem_req) {
    imem_grant = 1'b1;
    dmem_grant = 1'b0;
} else {
    imem_grant = 1'b0;
    dmem_grant = 1'b0;
}
```

**Signals:**
- `imem_req` - continuous (always trying to fetch next instruction)
- `dmem_req` - when CPU writes (|dmem_we) or reads from data space
- `imem_grant` - this cycle, IMEM can access memory
- `dmem_grant` - this cycle, DMEM can access memory
- `imem_wait` - stall the pipeline (IMEM denied access)
- `dmem_wait` - stall the pipeline (DMEM denied access, rare)

### 2. Wait State Controller (`bus_wait_ctrl.v`)

**Purpose:** Converts arbitrator wait signals into CPU pipeline stalls.

**Features:**
- Configurable wait cycle count per conflict (typically 1 cycle)
- Accumulates consecutive conflicts
- Outputs combined stall signal (`cpu_wait_o`)

**Logic:**
```verilog
if ((imem_wait_i || dmem_wait_i) && (wait_counter == 0)) {
    wait_counter = WAIT_CYCLES;  // preload on new conflict
} else if (wait_counter > 0) {
    wait_counter--;               // decrement each cycle
}
cpu_wait_o = (wait_counter > 0);  // stall while counting down
```

### 3. CPU Integration

**Modified `rv32e_core.v`:**
- New input port: `bus_wait` (from wait state controller)
- Stall logic updated:
  ```verilog
  assign stall = load_use_hazard || bus_wait;
  ```
- Pipeline freezes when either stall condition is true.

### 4. Top-Level Integration (`top.v`)

**Instantiation Order:**
1. CPU (rv32e_core) → generates imem_addr, imem_req, dmem_addr, dmem_req, dmem_we
2. Bus Arbitrator → receives requests, outputs grants/waits
3. Wait State Controller → converts waits to cpu_wait signal
4. Memory Block (mem_2r1w) → receives arbitrated requests

**Port Wiring:**
```verilog
imem_req = 1'b1;              // continuous fetch request
dmem_req = |dmem_we;          // write or data access request

bus_arbiter arb(
    .imem_req(imem_req),
    .imem_grant(imem_grant),
    .imem_wait(imem_wait),
    .dmem_req(dmem_req),
    .dmem_grant(dmem_grant),
    .dmem_wait(dmem_wait),
    ...
);

bus_wait_ctrl wait_ctrl(
    .imem_wait_i(imem_wait),
    .dmem_wait_i(dmem_wait),
    .cpu_wait_o(bus_wait)
);

cpu(
    .bus_wait(bus_wait),
    ...
);
```

## Wait State Scenarios

### Scenario 1: No Conflict (Normal Operation)
```
Cycle 1: imem_req=1, dmem_req=0
         → imem_grant=1, dmem_grant=0
         → bus_wait=0 (no stall)
Result:  Pipeline continues normally
```

### Scenario 2: Simultaneous IMEM + DMEM Write
```
Cycle 1: imem_req=1, dmem_req=1 (write)
         → imem_grant=0 (DMEM priority), dmem_grant=1
         → imem_wait=1, cpu_wait_o=1
         → CPU pipeline stalls
Cycle 2: wait_counter decrements to 0
         → cpu_wait_o=0
         → CPU resumes (retries IMEM fetch)
```

### Scenario 3: Consecutive Conflicts
```
Cycle 1: imem_req=1, dmem_req=1 (write)
         → cpu_wait_o=1, wait_counter=1
Cycle 2: imem_req=1, dmem_req=1 (still writing?)
         → wait_counter decrements but new conflict detected
         → wait_counter reloaded to 1
         → cpu_wait_o=1 (stall continues)
Cycle 3: dmem_req=0 (write complete)
         → wait_counter decrements to 0
         → cpu_wait_o=0
```

## Testing Strategy (UVM)

### Test Cases:

1. **bus_arbitration_priority_test**
   - Verify DMEM has priority over IMEM
   - Check imem_wait asserted when both request

2. **wait_state_insertion_test**
   - Confirm cpu_wait stalls the pipeline
   - Check PC frozen during stall
   - Verify correct instruction fetched after stall

3. **consecutive_conflicts_test**
   - Multiple simultaneous IMEM/DMEM accesses
   - Verify wait states accumulate correctly

4. **bus_load_stress_test**
   - Rapid DMEM writes + continuous IMEM fetch
   - Measure average wait cycles

### Coverage Metrics:

- **Functional Coverage:**
  - imem_req asserted / denied transitions
  - dmem_req asserted / denied transitions
  - wait_counter preload vs. decrement paths
  - cpu_wait rising / falling edges

- **Code Coverage:**
  - All arbitration decision branches
  - Wait counter saturation boundary (if any)
  - Reset behavior

## Performance Impact

**Penalty per conflict:** 1 wait cycle (configurable)

**Expected stall rate:**
- Sequential code (no memory conflicts): 0% stalls
- Code with frequent DMEM writes: 5–15% stalls
- Stress test (continuous writes): up to 50% stalls

## Future Enhancements

1. **Dynamic wait cycle adjustment:** based on memory type (BRAM vs. external)
2. **DMEM read arbitration:** currently treats all dmem_req equally (even reads)
3. **Prefetch buffers:** to reduce stall impact on instruction fetch
4. **Multi-level arbitration:** if adding peripheral ports (DMA, debug)
5. **Quality-of-Service (QoS) policies:** weighted priority, round-robin with aging

