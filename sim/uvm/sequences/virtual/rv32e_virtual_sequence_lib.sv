`ifndef RV32E_VIRTUAL_SEQUENCE_LIB_SV
`define RV32E_VIRTUAL_SEQUENCE_LIB_SV

/**
 * RV32E Virtual Sequence Library.
 * Virtual sequences that coordinate multiple agents.
 */

// ============================================================================
// Base Virtual Sequence
// ============================================================================
class rv32e_virtual_sequence extends uvm_sequence;

  `uvm_object_utils(rv32e_virtual_sequence)

  // Sequences to run
  rv32e_alu_seq          alu_seq;
  rv32e_load_store_seq   load_store_seq;
  rv32e_branch_seq       branch_seq;
  rv32e_csr_seq          csr_seq;
  rv32e_random_seq       random_seq;
  rv32e_alu_stress_seq   alu_stress_seq;
  rv32e_mem_stress_seq   mem_stress_seq;
  rv32e_zero_reg_seq     zero_reg_seq;
  rv32e_all_ones_seq     all_ones_seq;
  rv32e_unaligned_seq    unaligned_seq;
  rv32e_invalid_csr_seq  invalid_csr_seq;

  // Configuration
  rand int unsigned num_iterations = 1;
  rand int unsigned test_duration = 1000;

  constraint c_num_iterations {
    num_iterations >= 1;
    num_iterations <= 100;
  }

  constraint c_test_duration {
    test_duration >= 100;
    test_duration <= 10000;
  }

  function new(string name = "rv32e_virtual_sequence");
    super.new(name);
  endfunction : new

endclass : rv32e_virtual_sequence

// ============================================================================
// Random CPU Virtual Sequence
// ============================================================================
class rv32e_random_cpu_vseq extends rv32e_virtual_sequence;

  `uvm_object_utils(rv32e_random_cpu_vseq)

  function new(string name = "rv32e_random_cpu_vseq");
    super.new(name);
  endfunction : new

  task body();
    `uvm_info(get_type_name(), "Starting random CPU virtual sequence", UVM_LOW)

    // Start random sequence on CPU sequencer
    random_seq = rv32e_random_seq::type_id::create("random_seq");
    random_seq.num_instructions = 100;

    fork
      random_seq.start(p_sequencer.cpu_sequencer);
    join

    `uvm_info(get_type_name(), "Random CPU virtual sequence completed", UVM_LOW)
  endtask : body

endclass : rv32e_random_cpu_vseq

// ============================================================================
// ALU + Memory Virtual Sequence
// ============================================================================
class rv32e_alu_mem_vseq extends rv32e_virtual_sequence;

  `uvm_object_utils(rv32e_alu_mem_vseq)

  function new(string name = "rv32e_alu_mem_vseq");
    super.new(name);
  endfunction : new

  task body();
    `uvm_info(get_type_name(), "Starting ALU + Memory virtual sequence", UVM_LOW)

    // Start ALU sequence
    alu_seq = rv32e_alu_seq::type_id::create("alu_seq");
    alu_seq.num_instructions = 50;

    // Start load/store sequence
    load_store_seq = rv32e_load_store_seq::type_id::create("load_store_seq");
    load_store_seq.num_loads = 20;
    load_store_seq.num_stores = 20;

    fork
      alu_seq.start(p_sequencer.cpu_sequencer);
      load_store_seq.start(p_sequencer.cpu_sequencer);
    join

    `uvm_info(get_type_name(), "ALU + Memory virtual sequence completed", UVM_LOW)
  endtask : body

endclass : rv32e_alu_mem_vseq

// ============================================================================
// CSR + Branch Virtual Sequence
// ============================================================================
class rv32e_csr_branch_vseq extends rv32e_virtual_sequence;

  `uvm_object_utils(rv32e_csr_branch_vseq)

  function new(string name = "rv32e_csr_branch_vseq");
    super.new(name);
  endfunction : new

  task body();
    `uvm_info(get_type_name(), "Starting CSR + Branch virtual sequence", UVM_LOW)

    // Start CSR sequence
    csr_seq = rv32e_csr_seq::type_id::create("csr_seq");
    csr_seq.num_csr_ops = 20;

    // Start branch sequence
    branch_seq = rv32e_branch_seq::type_id::create("branch_seq");
    branch_seq.num_branches = 30;

    fork
      csr_seq.start(p_sequencer.cpu_sequencer);
      branch_seq.start(p_sequencer.cpu_sequencer);
    join

    `uvm_info(get_type_name(), "CSR + Branch virtual sequence completed", UVM_LOW)
  endtask : body

endclass : rv32e_csr_branch_vseq

// ============================================================================
// Stress Test Virtual Sequence
// ============================================================================
class rv32e_stress_vseq extends rv32e_virtual_sequence;

  `uvm_object_utils(rv32e_stress_vseq)

  function new(string name = "rv32e_stress_vseq");
    super.new(name);
  endfunction : new

  task body();
    `uvm_info(get_type_name(), "Starting stress test virtual sequence", UVM_LOW)

    // Start ALU stress sequence
    alu_stress_seq = rv32e_alu_stress_seq::type_id::create("alu_stress_seq");
    alu_stress_seq.num_instructions = 1000;

    // Start memory stress sequence
    mem_stress_seq = rv32e_mem_stress_seq::type_id::create("mem_stress_seq");
    mem_stress_seq.num_operations = 500;

    fork
      alu_stress_seq.start(p_sequencer.cpu_sequencer);
      mem_stress_seq.start(p_sequencer.cpu_sequencer);
    join

    `uvm_info(get_type_name(), "Stress test virtual sequence completed", UVM_LOW)
  endtask : body

endclass : rv32e_stress_vseq

// ============================================================================
// Integration Test Virtual Sequence
// ============================================================================
class rv32e_integration_vseq extends rv32e_virtual_sequence;

  `uvm_object_utils(rv32e_integration_vseq)

  function new(string name = "rv32e_integration_vseq");
    super.new(name);
  endfunction : new

  task body();
    `uvm_info(get_type_name(), "Starting integration test virtual sequence", UVM_LOW)

    // Run a complete test sequence
    fork
      // Initialize
      zero_reg_seq.start(p_sequencer.cpu_sequencer);
      
      // Main computation
      alu_seq.start(p_sequencer.cpu_sequencer);
      load_store_seq.start(p_sequencer.cpu_sequencer);
      branch_seq.start(p_sequencer.cpu_sequencer);
      csr_seq.start(p_sequencer.cpu_sequencer);
      
      // Corner cases
      unaligned_seq.start(p_sequencer.cpu_sequencer);
      invalid_csr_seq.start(p_sequencer.cpu_sequencer);
    join

    `uvm_info(get_type_name(), "Integration test virtual sequence completed", UVM_LOW)
  endtask : body

endclass : rv32e_integration_vseq

`endif // RV32E_VIRTUAL_SEQUENCE_LIB_SV
