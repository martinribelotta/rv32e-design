`ifndef RV32E_TEST_LIB_SV
`define RV32E_TEST_LIB_SV

/**
 * RV32E Test Library.
 * Contains all test classes for the RV32E verification environment.
 */
`include "rv32e_base_test.sv"

// ============================================================================
// Smoke Test
// ============================================================================
class rv32e_smoke_test extends rv32e_base_test;

  `uvm_component_utils(rv32e_smoke_test)

  function new(string name = "rv32e_smoke_test", uvm_component parent = null);
    super.new(name, parent);
    m_test_name = "rv32e_smoke_test";
  endfunction : new

  task run_phase(uvm_phase phase);
    rv32e_random_seq seq;

    `uvm_info(get_type_name(), "Running smoke test", UVM_LOW)

    phase.raise_objection(this, "Smoke test");

    // Run a short random sequence
    seq = rv32e_random_seq::type_id::create("seq");
    seq.num_instructions = 10;

    // Start sequence on CPU sequencer
    // seq.start(m_env.cpu_agent.m_sequencer);

    #100us;

    phase.drop_objection(this, "Smoke test completed");
  endtask : run_phase

endclass : rv32e_smoke_test

// ============================================================================
// ALU Test
// ============================================================================
class rv32e_alu_test extends rv32e_base_test;

  `uvm_component_utils(rv32e_alu_test)

  function new(string name = "rv32e_alu_test", uvm_component parent = null);
    super.new(name, parent);
    m_test_name = "rv32e_alu_test";
  endfunction : new

  task run_phase(uvm_phase phase);
    rv32e_alu_seq seq;

    `uvm_info(get_type_name(), "Running ALU test", UVM_LOW)

    phase.raise_objection(this, "ALU test");

    seq = rv32e_alu_seq::type_id::create("seq");
    seq.num_instructions = 100;

    // seq.start(m_env.cpu_agent.m_sequencer);

    #100us;

    phase.drop_objection(this, "ALU test completed");
  endtask : run_phase

endclass : rv32e_alu_test

// ============================================================================
// Load/Store Test
// ============================================================================
class rv32e_load_store_test extends rv32e_base_test;

  `uvm_component_utils(rv32e_load_store_test)

  function new(string name = "rv32e_load_store_test", uvm_component parent = null);
    super.new(name, parent);
    m_test_name = "rv32e_load_store_test";
  endfunction : new

  task run_phase(uvm_phase phase);
    rv32e_load_store_seq seq;

    `uvm_info(get_type_name(), "Running Load/Store test", UVM_LOW)

    phase.raise_objection(this, "Load/Store test");

    seq = rv32e_load_store_seq::type_id::create("seq");
    seq.num_loads = 50;
    seq.num_stores = 50;

    // seq.start(m_env.cpu_agent.m_sequencer);

    #100us;

    phase.drop_objection(this, "Load/Store test completed");
  endtask : run_phase

endclass : rv32e_load_store_test

// ============================================================================
// Branch Test
// ============================================================================
class rv32e_branch_test extends rv32e_base_test;

  `uvm_component_utils(rv32e_branch_test)

  function new(string name = "rv32e_branch_test", uvm_component parent = null);
    super.new(name, parent);
    m_test_name = "rv32e_branch_test";
  endfunction : new

  task run_phase(uvm_phase phase);
    rv32e_branch_seq seq;

    `uvm_info(get_type_name(), "Running Branch test", UVM_LOW)

    phase.raise_objection(this, "Branch test");

    seq = rv32e_branch_seq::type_id::create("seq");
    seq.num_branches = 50;

    // seq.start(m_env.cpu_agent.m_sequencer);

    #100us;

    phase.drop_objection(this, "Branch test completed");
  endtask : run_phase

endclass : rv32e_branch_test

// ============================================================================
// CSR Test
// ============================================================================
class rv32e_csr_test extends rv32e_base_test;

  `uvm_component_utils(rv32e_csr_test)

  function new(string name = "rv32e_csr_test", uvm_component parent = null);
    super.new(name, parent);
    m_test_name = "rv32e_csr_test";
  endfunction : new

  task run_phase(uvm_phase phase);
    rv32e_csr_seq seq;

    `uvm_info(get_type_name(), "Running CSR test", UVM_LOW)

    phase.raise_objection(this, "CSR test");

    seq = rv32e_csr_seq::type_id::create("seq");
    seq.num_csr_ops = 50;

    // seq.start(m_env.cpu_agent.m_sequencer);

    #100us;

    phase.drop_objection(this, "CSR test completed");
  endtask : run_phase

endclass : rv32e_csr_test

// ============================================================================
// Stress Test
// ============================================================================
class rv32e_stress_test extends rv32e_base_test;

  `uvm_component_utils(rv32e_stress_test)

  function new(string name = "rv32e_stress_test", uvm_component parent = null);
    super.new(name, parent);
    m_test_name = "rv32e_stress_test";
    m_max_cycles = 500000;
  endfunction : new

  task run_phase(uvm_phase phase);
    rv32e_alu_stress_seq alu_seq;
    rv32e_mem_stress_seq mem_seq;

    `uvm_info(get_type_name(), "Running stress test", UVM_LOW)

    phase.raise_objection(this, "Stress test");

    // ALU stress sequence
    alu_seq = rv32e_alu_stress_seq::type_id::create("alu_seq");
    alu_seq.num_instructions = 1000;

    // Memory stress sequence
    mem_seq = rv32e_mem_stress_seq::type_id::create("mem_seq");
    mem_seq.num_operations = 500;

    // Fork both sequences
    fork
      alu_seq.start(m_env.cpu_agent.m_sequencer);
      mem_seq.start(m_env.cpu_agent.m_sequencer);
    join

    #500us;

    phase.drop_objection(this, "Stress test completed");
  endtask : run_phase

endclass : rv32e_stress_test

// ============================================================================
// Integration Test
// ============================================================================
class rv32e_integration_test extends rv32e_base_test;

  `uvm_component_utils(rv32e_integration_test)

  function new(string name = "rv32e_integration_test", uvm_component parent = null);
    super.new(name, parent);
    m_test_name = "rv32e_integration_test";
  endfunction : new

  task run_phase(uvm_phase phase);
    rv32e_integration_vseq vseq;

    `uvm_info(get_type_name(), "Running integration test", UVM_LOW)

    phase.raise_objection(this, "Integration test");

    vseq = rv32e_integration_vseq::type_id::create("vseq");

    // vseq.start(m_env.cpu_agent.m_sequencer);

    #200us;

    phase.drop_objection(this, "Integration test completed");
  endtask : run_phase

endclass : rv32e_integration_test

// ============================================================================
// Random Test
// ============================================================================
class rv32e_random_test extends rv32e_base_test;

  `uvm_component_utils(rv32e_random_test)

  function new(string name = "rv32e_random_test", uvm_component parent = null);
    super.new(name, parent);
    m_test_name = "rv32e_random_test";
  endfunction : new

  task run_phase(uvm_phase phase);
    rv32e_random_seq seq;

    `uvm_info(get_type_name(), "Running random test", UVM_LOW)

    phase.raise_objection(this, "Random test");

    seq = rv32e_random_seq::type_id::create("seq");
    seq.num_instructions = 500;

    // seq.start(m_env.cpu_agent.m_sequencer);

    #200us;

    phase.drop_objection(this, "Random test completed");
  endtask : run_phase

endclass : rv32e_random_test

// ============================================================================
// Backdoor Test
// ============================================================================
class rv32e_backdoor_test extends rv32e_base_test;

  `uvm_component_utils(rv32e_backdoor_test)

  function new(string name = "rv32e_backdoor_test", uvm_component parent = null);
    super.new(name, parent);
    m_test_name = "rv32e_backdoor_test";
  endfunction : new

  task run_phase(uvm_phase phase);
    rv32e_seq_item item;

    `uvm_info(get_type_name(), "Running backdoor test", UVM_LOW)

    phase.raise_objection(this, "Backdoor test");

    // Write to registers via backdoor
    // m_env.m_reg_model.mstatus.write(.status(UVM_BACKDOOR), .value(32'h800));

    #50us;

    phase.drop_objection(this, "Backdoor test completed");
  endtask : run_phase

endclass : rv32e_backdoor_test

// ============================================================================
// Error Test
// ============================================================================
class rv32e_error_test extends rv32e_base_test;

  `uvm_component_utils(rv32e_error_test)

  function new(string name = "rv32e_error_test", uvm_component parent = null);
    super.new(name, parent);
    m_test_name = "rv32e_error_test";
  endfunction : new

  task run_phase(uvm_phase phase);
    rv32e_unaligned_seq unaligned_seq;
    rv32e_invalid_csr_seq invalid_csr_seq;

    `uvm_info(get_type_name(), "Running error test", UVM_LOW)

    phase.raise_objection(this, "Error test");

    // Generate unaligned accesses
    unaligned_seq = rv32e_unaligned_seq::type_id::create("unaligned_seq");

    // Generate invalid CSR accesses
    invalid_csr_seq = rv32e_invalid_csr_seq::type_id::create("invalid_csr_seq");

    // unaligned_seq.start(m_env.cpu_agent.m_sequencer);
    // invalid_csr_seq.start(m_env.cpu_agent.m_sequencer);

    #50us;

    phase.drop_objection(this, "Error test completed");
  endtask : run_phase

endclass : rv32e_error_test

`endif // RV32E_TEST_LIB_SV
