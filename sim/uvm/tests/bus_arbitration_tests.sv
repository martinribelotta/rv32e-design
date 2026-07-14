`ifndef BUS_ARBITRATION_TESTS_SV
`define BUS_ARBITRATION_TESTS_SV

`include "uvm_macros.svh"
import uvm_pkg::*;

/**
 * Bus Arbitration Test: Base class for all bus arbitration tests
 */
class bus_arbitration_base_test extends uvm_test;
  `uvm_component_utils(bus_arbitration_base_test)

  rv32e_env m_env;

  function new(string name = "bus_arbitration_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    m_env = rv32e_env::type_id::create("m_env", this);
  endfunction : build_phase

  virtual task run_phase(uvm_phase phase);
    // Default: do nothing (override in derived tests)
  endtask : run_phase

endclass : bus_arbitration_base_test

/**
 * Test 1: Bus Stress Test
 * Generates high DMEM write frequency to stress bus arbitration.
 * Expected: CPU stalls during conflicts, resumes after wait states.
 */
class bus_stress_test extends bus_arbitration_base_test;
  `uvm_component_utils(bus_stress_test)

  function new(string name = "bus_stress_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  task run_phase(uvm_phase phase);
    bus_stress_sequence stress_seq;
    phase.raise_objection(this);

    `uvm_info("bus_stress_test", "Starting bus stress test", UVM_MEDIUM)

    stress_seq = bus_stress_sequence::type_id::create("stress_seq");
    stress_seq.num_stress_cycles = 30;
    stress_seq.dmem_write_prob = 80;  // 80% store instructions

    // Execute the stress sequence through the virtual sequencer
    assert(stress_seq.randomize());
    stress_seq.start(m_env.m_virtual_sequencer);

    `uvm_info("bus_stress_test", "Bus stress test completed", UVM_MEDIUM)

    phase.drop_objection(this);
  endtask : run_phase

endclass : bus_stress_test

/**
 * Test 2: Bus Priority Test
 * Verifies DMEM (data) priority over IMEM (instruction) fetch.
 * Expected: DMEM writes always granted first, IMEM waits.
 */
class bus_priority_test extends bus_arbitration_base_test;
  `uvm_component_utils(bus_priority_test)

  function new(string name = "bus_priority_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  task run_phase(uvm_phase phase);
    bus_priority_sequence priority_seq;
    phase.raise_objection(this);

    `uvm_info("bus_priority_test", "Starting bus priority test", UVM_MEDIUM)

    priority_seq = bus_priority_sequence::type_id::create("priority_seq");
    assert(priority_seq.randomize());
    priority_seq.start(m_env.m_virtual_sequencer);

    `uvm_info("bus_priority_test", "Bus priority test completed", UVM_MEDIUM)

    phase.drop_objection(this);
  endtask : run_phase

endclass : bus_priority_test

/**
 * Test 3: Consecutive Conflicts Test
 * Tests back-to-back bus conflicts.
 * Expected: Wait states accumulate, then dissipate as conflicts cease.
 */
class bus_consecutive_conflicts_test extends bus_arbitration_base_test;
  `uvm_component_utils(bus_consecutive_conflicts_test)

  function new(string name = "bus_consecutive_conflicts_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  task run_phase(uvm_phase phase);
    bus_consecutive_conflicts_sequence conflicts_seq;
    phase.raise_objection(this);

    `uvm_info("bus_consecutive_conflicts_test", "Starting consecutive conflicts test", UVM_MEDIUM)

    conflicts_seq = bus_consecutive_conflicts_sequence::type_id::create("conflicts_seq");
    assert(conflicts_seq.randomize());
    conflicts_seq.start(m_env.m_virtual_sequencer);

    `uvm_info("bus_consecutive_conflicts_test", "Consecutive conflicts test completed", UVM_MEDIUM)

    phase.drop_objection(this);
  endtask : run_phase

endclass : bus_consecutive_conflicts_test

/**
 * Test 4: No Conflict Test
 * Baseline test: normal instruction execution with minimal DMEM access.
 * Expected: No wait states, normal throughput.
 */
class bus_no_conflict_test extends bus_arbitration_base_test;
  `uvm_component_utils(bus_no_conflict_test)

  function new(string name = "bus_no_conflict_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  task run_phase(uvm_phase phase);
    bus_stress_sequence clean_seq;
    phase.raise_objection(this);

    `uvm_info("bus_no_conflict_test", "Starting no-conflict baseline test", UVM_MEDIUM)

    clean_seq = bus_stress_sequence::type_id::create("clean_seq");
    clean_seq.num_stress_cycles = 20;
    clean_seq.dmem_write_prob = 10;  // Only 10% writes (mostly reads/ALU ops)

    assert(clean_seq.randomize());
    clean_seq.start(m_env.m_virtual_sequencer);

    `uvm_info("bus_no_conflict_test", "No-conflict test completed", UVM_MEDIUM)

    phase.drop_objection(this);
  endtask : run_phase

endclass : bus_no_conflict_test

`endif // BUS_ARBITRATION_TESTS_SV
