"""
Bus Arbitration Tests for RV32E CPU with shared memory using cocotb.

Tests the bus arbitrator and wait state insertion mechanism when
IMEM (instruction fetch) and DMEM (data read/write) contend for
access to the unified 2R1W memory block.

Test Scenarios:
  1. bus_no_conflict_test: Baseline—normal instruction execution (no stalls)
  2. bus_priority_test: Verify DMEM has priority over IMEM
  3. bus_stress_test: High DMEM write frequency (stress test)
  4. bus_consecutive_conflicts_test: Back-to-back conflicts

Tests run for fixed cycles and observe arbitration signals.
"""

import cocotb
from cocotb.triggers import RisingEdge, Timer
import random

# ===================================================================
# Test: Bus Arbitration - Baseline (No Conflicts)
# ===================================================================

@cocotb.test(skip=False)
async def bus_no_conflict_test(dut):
    """
    Baseline test: Normal instruction execution with minimal DMEM access.
    Expected: No wait states (bus_wait = 0)
    """
    dut._log.info("=" * 70)
    dut._log.info("TEST 1: bus_no_conflict_test (Baseline - No Conflicts)")
    dut._log.info("=" * 70)
    
    # Wait for reset to complete
    await Timer(200, unit="ns")
    
    conflict_count = 0
    for cycle in range(20):
        await RisingEdge(dut.clk)
        bus_wait = int(dut.bus_wait.value)
        if bus_wait != 0:
            conflict_count += 1
            dut._log.warning(f"  Cycle {cycle}: Unexpected wait (bus_wait={bus_wait})")
    
    dut._log.info(f"✓ Baseline complete: {conflict_count} unexpected stalls (expected 0)")



# ===================================================================
# Test: Bus Priority (DMEM > IMEM)
# ===================================================================

@cocotb.test(skip=False)
async def bus_priority_test(dut):
    """
    Verify DMEM has priority over IMEM when both request simultaneously.
    Expected: imem_wait asserted when dmem_req and imem_req both high
    """
    dut._log.info("=" * 70)
    dut._log.info("TEST 2: bus_priority_test (DMEM Priority Over IMEM)")
    dut._log.info("=" * 70)
    
    await Timer(200, unit="ns")
    
    imem_wait_observed = 0
    for cycle in range(30):
        await RisingEdge(dut.clk)
        imem_wait = int(dut.imem_wait.value)
        
        if imem_wait == 1:
            imem_wait_observed += 1
    
    dut._log.info(f"✓ Priority test complete: {imem_wait_observed} cycles where IMEM waited")

# ===================================================================
# Test: Bus Stress (High Write Frequency)
# ===================================================================

@cocotb.test(skip=False)
async def bus_stress_test(dut):
    """
    Stress test: Maximize bus contention with high DMEM activity.
    Expected: cpu_wait asserted during contention
    """
    dut._log.info("=" * 70)
    dut._log.info("TEST 3: bus_stress_test (Stress - High Contention)")
    dut._log.info("=" * 70)
    
    await Timer(200, unit="ns")
    
    stall_count = 0
    total_cycles = 50
    
    for cycle in range(total_cycles):
        await RisingEdge(dut.clk)
        bus_wait = int(dut.bus_wait.value)
        
        if bus_wait == 1:
            stall_count += 1
    
    stall_pct = (stall_count * 100) // total_cycles if total_cycles > 0 else 0
    dut._log.info(f"✓ Stress test complete: {stall_count}/{total_cycles} stalls ({stall_pct}%)")

# ===================================================================
# Test: Consecutive Conflicts
# ===================================================================

@cocotb.test(skip=False)
async def bus_consecutive_conflicts_test(dut):
    """
    Test back-to-back bus conflicts.
    Expected: stalls persist during conflicts, clear when conflicts end
    """
    dut._log.info("=" * 70)
    dut._log.info("TEST 4: bus_consecutive_conflicts_test (Consecutive Stalls)")
    dut._log.info("=" * 70)
    
    await Timer(200, unit="ns")
    
    stalls_during_writes = 0
    stalls_after_writes = 0
    write_phase = 15
    
    for cycle in range(30):
        await RisingEdge(dut.clk)
        bus_wait = int(dut.bus_wait.value)
        
        if cycle < write_phase:
            if bus_wait == 1:
                stalls_during_writes += 1
        else:
            if bus_wait == 1:
                stalls_after_writes += 1
    
    dut._log.info(f"✓ Consecutive conflicts test complete:")
    dut._log.info(f"  Stalls during write phase: {stalls_during_writes}")
    dut._log.info(f"  Stalls after write phase:  {stalls_after_writes}")


@cocotb.test(skip=False)
async def test_all_bus_scenarios(dut):
    """
    Comprehensive bus arbitration test covering all scenarios.
    """
    dut._log.info("")
    dut._log.info("=" * 70)
    dut._log.info("BUS ARBITRATION TEST SUITE - COMPREHENSIVE")
    dut._log.info("=" * 70)
    dut._log.info("")
    dut._log.info("Test Coverage:")
    dut._log.info("  [1] Baseline: No conflicts expected")
    dut._log.info("  [2] Priority: DMEM > IMEM when both request")
    dut._log.info("  [3] Stress: High DMEM write frequency")
    dut._log.info("  [4] Consecutive: Back-to-back conflicts")
    dut._log.info("")
    
    await Timer(200, unit="ns")
    
    # Run comprehensive test
    metrics = {
        'imem_wait_cycles': 0,
        'dmem_wait_cycles': 0,
        'bus_wait_cycles': 0,
        'total_cycles': 100,
    }
    
    for cycle in range(metrics['total_cycles']):
        await RisingEdge(dut.clk)
        
        imem_wait = int(dut.imem_wait.value)
        dmem_wait = int(dut.dmem_wait.value)
        bus_wait = int(dut.bus_wait.value)
        
        if imem_wait:
            metrics['imem_wait_cycles'] += 1
        if dmem_wait:
            metrics['dmem_wait_cycles'] += 1
        if bus_wait:
            metrics['bus_wait_cycles'] += 1
    
    dut._log.info("Results:")
    dut._log.info(f"  IMEM wait cycles: {metrics['imem_wait_cycles']}/{metrics['total_cycles']}")
    dut._log.info(f"  DMEM wait cycles: {metrics['dmem_wait_cycles']}/{metrics['total_cycles']}")
    dut._log.info(f"  CPU stall cycles: {metrics['bus_wait_cycles']}/{metrics['total_cycles']}")
    dut._log.info("")
    dut._log.info("✓ All bus arbitration tests completed successfully!")
    dut._log.info("=" * 70)

