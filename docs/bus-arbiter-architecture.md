# Bus Arbiter Architecture Diagram

## System Block Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          RV32E CPU Core                                  │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  3-Stage Pipeline: IF | ID/EX | MEM/WB                          │   │
│  │                                                                  │   │
│  │  Stall Logic:                                                    │   │
│  │    stall = load_use_hazard || bus_wait    ◄─── NEW: bus_wait    │   │
│  │                                                                  │   │
│  │  When stall=1: PC frozen, regs held, BRAM re-reads same addrs   │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│         │ imem_addr, imem_req (continuous)                             │
│         │                                                               │
│         │ dmem_addr, dmem_wdata, dmem_we, dmem_req (gated by writes)   │
│         │                                                               │
└─────────┼───────────────────────────────────────────────────────────────┘
          │
          │  PORT REQUESTS
          │
          ├─────────────────────────────────────────────────────────────────┐
          │                                                                 │
          │  ┌────────────────────────────────────────────────────────┐   │
          │  │  BUS ARBITRATOR (bus_arbiter.v)                        │   │
          │  │  ═════════════════════════════════════════════════════ │   │
          │  │                                                        │   │
          │  │  Inputs:                                               │   │
          │  │    imem_req ────────────► Continuous fetch request    │   │
          │  │    dmem_req ────────────► Write or data access req   │   │
          │  │                                                        │   │
          │  │  Priority Logic:                                       │   │
          │  │    if (dmem_req)  → DMEM_GRANT = 1 ◄─ HIGH priority  │   │
          │  │    else if (imem_req) → IMEM_GRANT = 1 ◄─ LOW priority│   │
          │  │                                                        │   │
          │  │  Outputs:                                              │   │
          │  │    imem_grant ─────► IMEM can access this cycle      │   │
          │  │    imem_wait ──────► IMEM request denied, stall      │   │
          │  │    dmem_grant ─────► DMEM can access this cycle      │   │
          │  │    dmem_wait ──────► DMEM request denied (rare)      │   │
          │  │                                                        │   │
          │  └────────────────────────────────────────────────────────┘   │
          │         │ imem_wait, dmem_wait                                 │
          │         │                                                      │
          ├─────────┼─────────────────────────────────────────────────────┐
          │         │                                                     │
          │         │  ┌──────────────────────────────────────────────┐  │
          │         │  │  WAIT STATE CONTROLLER (bus_wait_ctrl.v)    │  │
          │         │  │  ═════════════════════════════════════════  │  │
          │         │  │                                              │  │
          │         └─►│  Inputs:                                     │  │
          │            │    imem_wait_i ─────────────────────────┐  │  │
          │            │    dmem_wait_i ─────────────────────────┤  │  │
          │            │                                      ┌───┤  │  │
          │            │  Wait Counter Logic:                 │   │  │  │
          │            │    if (imem_wait || dmem_wait) {     │   │  │  │
          │            │      wait_counter = WAIT_CYCLES;    │   │  │  │
          │            │    } else if (wait_counter > 0) {   │   │  │  │
          │            │      wait_counter--;                │   │  │  │
          │            │    }                                │   │  │  │
          │            │                                      └───┤  │  │
          │            │  Outputs:                                │  │  │
          │            │    cpu_wait_o ────────────────────────┐  │  │  │
          │            │                                        │  │  │  │
          │            └──────────────────────────────────────────┘  │  │
          │                                                           │  │
          ├───────────────────────────────────────────────────────────┤  │
          │                                                           │  │
          │  cpu_wait_o ─────────────────────────────────────────────┘  │
          │    │                                                        │
          ▼    │                                                        │
     ┌─────┴────────┐                                                  │
     │               │                                                 │
     │ CPU:          │                                                 │
     │ stall =       │         (frozen until wait counter = 0)        │
     │ load_use ||   │                                                 │
     │ cpu_wait      │                                                 │
     │               │                                                 │
     └───────────────┘                                                 │
                                                                       │
          ┌───────────────────────────────────────────────────────────┘
          │
          │  ARBITRATED ACCESS
          │
          ▼
     ┌─────────────────────────────────────────────┐
     │   Unified 2R1W Memory (mem_2r1w.v)          │
     │  ═════════════════════════════════════════  │
     │                                             │
     │  Port 0 (Read-only):                        │
     │    IMEM ROM (1024 words, icebram)           │
     │    Address: 0x0000-0x0FFF                   │
     │                                             │
     │  Port 1 (Read/Write):                       │
     │    DROM: 0x1000-0x17FF (512w, ROM)          │
     │    DRAM: 0x1800-0x1EFF (512w, RAM)          │
     │                                             │
     └─────────────────────────────────────────────┘
```

## Arbitration Timing Diagram

### Scenario A: No Conflict (Normal Operation)

```
Cycle:        1         2         3         4
              ├─────────┼─────────┼─────────┤
imem_req:     1         1         1         1        (continuous)
dmem_req:     0         0         0         0        (no writes)
              │         │         │         │
imem_grant:   1         1         1         1        (always granted)
imem_wait:    0         0         0         0
dmem_grant:   0         0         0         0
dmem_wait:    0         0         0         0
              │         │         │         │
cpu_wait:     0         0         0         0        (no stall)
              │         │         │         │
Fetch:       instr1    instr2    instr3    instr4   (continuous fetch)
```

### Scenario B: IMEM + DMEM Conflict

```
Cycle:        1         2         3         4
              ├─────────┼─────────┼─────────┤
imem_req:     1         1         1         1
dmem_req:     0         1         0         0        (write in cycle 2)
              │         │         │         │
imem_grant:   1         0         1         1        (denied in cycle 2)
imem_wait:    0         1         0         0
dmem_grant:   0         1         0         0
dmem_wait:    0         0         0         0
              │         │         │         │
wait_counter: 0         1         0         0        (count down from 1)
              │         │         │         │
cpu_wait:     0         1         0         0        (pipeline stall in cycle 2)
              │         │         │         │
PC:         [x]       [x]       [x]      [x+4]      (frozen in cycle 2, advances in 3)
Fetch:      instr@x  (stall)   retry@x  instr@x+4  (retry fetch after stall)
Write:      (none)  write_ok  (none)    (none)
```

### Scenario C: Consecutive Conflicts

```
Cycle:        1         2         3         4         5         6
              ├─────────┼─────────┼─────────┼─────────┼─────────┤
imem_req:     1         1         1         1         1         1
dmem_req:     1         1         1         0         0         0     (3 writes)
              │         │         │         │         │         │
imem_grant:   0         0         0         1         1         1
dmem_grant:   1         1         1         0         0         0
              │         │         │         │         │         │
wait_counter: 1         1         1         0         0         0
              │         │         │         │         │         │
cpu_wait:     1         1         1         0         0         0     (stall 3 cycles)
              │         │         │         │         │         │
PC:         [x]       [x]       [x]       [x]      [x+4]     [x+8]   (frozen for 4 cycles)
Data Access: write1   write2    write3    (none)    (none)   (none)
```

## Priority Arbitration Truth Table

| imem_req | dmem_req | imem_grant | dmem_grant | imem_wait | dmem_wait |
|:--------:|:--------:|:----------:|:----------:|:---------:|:---------:|
|    0     |    0     |     0      |     0      |     0     |     0     |
|    1     |    0     |     1      |     0      |     0     |     0     |
|    0     |    1     |     0      |     1      |     0     |     0     |
|    1     |    1     |     0      |     1      |     1     |     0     |

**Key:** DMEM gets priority when both request simultaneously.

## Performance Analysis

### Throughput Impact

```
Scenario                    Stall Rate    Throughput   Notes
────────────────────────────────────────────────────────────────
Sequential code (no DMEM)   0%            100%         Baseline
Normal workload (10% writes) 5-10%        90-95%       Acceptable
Write-heavy (50% writes)    20-30%        70-80%       Degraded
Stress test (80% writes)    40-50%        50-60%       Maximum contention
```

### Wait State Latency Breakdown

```
Event                           Cycles  Description
────────────────────────────────────────────────────────────
Normal DMEM write               1       Granted immediately
DMEM write (conflicts IMEM)     1       IMEM stalled 1 cycle
Consecutive writes (3x)         3       IMEM stalled 3 cycles
IMEM fetch (no conflict)        1       Free-running fetch
IMEM fetch (after conflict)     2       Re-fetch after stall
```

## Signal Flow Summary

```
┌─────────────────────────────────────────────────────────────┐
│ Input Signals                                               │
├─────────────────────────────────────────────────────────────┤
│ • imem_req:      Driven by rv32e_core (always 1)            │
│ • dmem_req:      Driven by top.v (= |dmem_we|)             │
│ • clk, rst_n:    Clock and reset                            │
└─────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────┐
│ Bus Arbitrator                                              │
├─────────────────────────────────────────────────────────────┤
│ • Combinational priority logic                              │
│ • DMEM > IMEM priority (hardcoded)                          │
│ • No state (no flip-flops)                                  │
└─────────────────────────────────────────────────────────────┘
         │
         ├─────────────────────────┐
         │                         │
         ▼                         ▼
    imem_wait               dmem_wait
    (async)                 (async)
         │                    │
         └────────┬───────────┘
                  │
                  ▼
         ┌─────────────────────┐
         │ Wait State Controller │
         ├─────────────────────┤
         │ • wait_counter (reg) │
         │ • cpu_wait_o (comb)  │
         └─────────────────────┘
                  │
                  ▼
            cpu_wait_o
         (to CPU stall logic)
```

## Module Instantiation Hierarchy

```
top.v
├── rv32e_core (CPU)
│   └── stall = load_use_hazard || bus_wait  ◄─── Key modification
├── bus_arbiter (NEW)
│   ├── imem_req ──┐
│   └── dmem_req ──┼─► Priority logic ─► imem_wait, dmem_wait
│                  └─► (combinational)
└── bus_wait_ctrl (NEW)
    ├── imem_wait ─┐
    ├── dmem_wait ─┼─► Wait counter ─► cpu_wait_o
    └── clk/rst_n ─┘
```

## Future Enhancements

### 1. Configurable Priority Schemes
- **Round-robin:** alternate priority each cycle
- **Weighted:** ratio-based (e.g., 3:1 DMEM:IMEM)
- **Aging:** boost starved port priority over time

### 2. Prefetch Buffer
- Cache next instruction to reduce IMEM stall impact
- Overlap IMEM fetch with DMEM access

### 3. Shared Bus with Multiple Ports
- Add DMA port (high priority)
- Add debug port (lowest priority)
- Extend arbitrator to N-way priority matrix

### 4. QoS Metrics
- Track stall cycles per port
- Implement fairness counters
- Report coverage via $fwrite to test logs

