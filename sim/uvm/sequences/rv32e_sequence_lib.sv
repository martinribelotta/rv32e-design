`ifndef RV32E_SEQUENCE_LIB_SV
`define RV32E_SEQUENCE_LIB_SV

/**
 * RV32E Sequence Library.
 * Contains all sequences for the RV32E verification environment.
 */

// ============================================================================
// Base Sequence
// ============================================================================
class rv32e_base_sequence extends uvm_sequence#(rv32e_seq_item);

  `uvm_object_utils(rv32e_base_sequence)

  function new(string name = "rv32e_base_sequence");
    super.new(name);
  endfunction : new

endclass : rv32e_base_sequence

// ============================================================================
// Directed Sequences
// ============================================================================

// ALU instruction sequence
class rv32e_alu_seq extends rv32e_base_sequence;

  rand int unsigned num_instructions = 10;

  constraint c_num_instructions {
    num_instructions >= 1;
    num_instructions <= 100;
  }

  `uvm_object_utils(rv32e_alu_seq)

  function new(string name = "rv32e_alu_seq");
    super.new(name);
  endfunction : new

  task body();
    rv32e_seq_item item;

    repeat (num_instructions) begin
      item = rv32e_seq_item::type_id::create("item");
      start_item(item);
      item.randomize() with {
        is_alu_r == 1;
        is_load == 0;
        is_store == 0;
        is_branch == 0;
        is_jal == 0;
        is_jalr == 0;
        is_lui == 0;
        is_auipc == 0;
        is_csr == 0;
      };
      finish_item(item);
    end
  endtask : body

endclass : rv32e_alu_seq

// Load/store sequence
class rv32e_load_store_seq extends rv32e_base_sequence;

  rand int unsigned num_loads = 5;
  rand int unsigned num_stores = 5;

  constraint c_num_ops {
    num_loads >= 1;
    num_loads <= 50;
    num_stores >= 1;
    num_stores <= 50;
  }

  `uvm_object_utils(rv32e_load_store_seq)

  function new(string name = "rv32e_load_store_seq");
    super.new(name);
  endfunction : new

  task body();
    rv32e_seq_item item;

    // Generate stores first
    repeat (num_stores) begin
      item = rv32e_seq_item::type_id::create("item");
      start_item(item);
      item.randomize() with {
        is_store == 1;
        is_load == 0;
        is_alu_r == 0;
        is_alu_i == 0;
        mem_addr[1:0] == 2'b00;
        mem_be != 4'b0000;
      };
      finish_item(item);
    end

    // Generate loads
    repeat (num_loads) begin
      item = rv32e_seq_item::type_id::create("item");
      start_item(item);
      item.randomize() with {
        is_load == 1;
        is_store == 0;
        is_alu_r == 0;
        is_alu_i == 0;
        mem_addr[1:0] == 2'b00;
      };
      finish_item(item);
    end
  endtask : body

endclass : rv32e_load_store_seq

// Branch sequence
class rv32e_branch_seq extends rv32e_base_sequence;

  rand int unsigned num_branches = 5;

  constraint c_num_branches {
    num_branches >= 1;
    num_branches <= 50;
  }

  `uvm_object_utils(rv32e_branch_seq)

  function new(string name = "rv32e_branch_seq");
    super.new(name);
  endfunction : new

  task body();
    rv32e_seq_item item;

    repeat (num_branches) begin
      item = rv32e_seq_item::type_id::create("item");
      start_item(item);
      item.randomize() with {
        is_branch == 1;
        is_alu_r == 0;
        is_alu_i == 0;
        is_load == 0;
        is_store == 0;
      };
      finish_item(item);
    end
  endtask : body

endclass : rv32e_branch_seq

// CSR sequence
class rv32e_csr_seq extends rv32e_base_sequence;

  rand int unsigned num_csr_ops = 10;

  constraint c_num_csr_ops {
    num_csr_ops >= 1;
    num_csr_ops <= 50;
  }

  `uvm_object_utils(rv32e_csr_seq)

  function new(string name = "rv32e_csr_seq");
    super.new(name);
  endfunction : new

  task body();
    rv32e_seq_item item;

    repeat (num_csr_ops) begin
      item = rv32e_seq_item::type_id::create("item");
      start_item(item);
      item.randomize() with {
        is_csr == 1;
        is_alu_r == 0;
        is_alu_i == 0;
        is_load == 0;
        is_store == 0;
        is_branch == 0;
        is_jal == 0;
        is_jalr == 0;
        csr_addr inside {12'h300, 12'h304, 12'h305, 12'h341, 12'h342, 12'h344};
      };
      finish_item(item);
    end
  endtask : body

endclass : rv32e_csr_seq

// ============================================================================
// Random Sequences
// ============================================================================

// Random instruction sequence
class rv32e_random_seq extends rv32e_base_sequence;

  rand int unsigned num_instructions = 100;

  constraint c_num_instructions {
    num_instructions >= 10;
    num_instructions <= 1000;
  }

  `uvm_object_utils(rv32e_random_seq)

  function new(string name = "rv32e_random_seq");
    super.new(name);
  endfunction : new

  task body();
    rv32e_seq_item item;

    repeat (num_instructions) begin
      item = rv32e_seq_item::type_id::create("item");
      start_item(item);
      item.randomize();
      finish_item(item);
    end
  endtask : body

endclass : rv32e_random_seq

// ============================================================================
// Stress Sequences
// ============================================================================

// Back-to-back ALU sequence
class rv32e_alu_stress_seq extends rv32e_base_sequence;

  rand int unsigned num_instructions = 500;

  constraint c_num_instructions {
    num_instructions >= 100;
    num_instructions <= 10000;
  }

  `uvm_object_utils(rv32e_alu_stress_seq)

  function new(string name = "rv32e_alu_stress_seq");
    super.new(name);
  endfunction : new

  task body();
    rv32e_seq_item item;

    repeat (num_instructions) begin
      item = rv32e_seq_item::type_id::create("item");
      start_item(item);
      item.randomize() with {
        is_alu_r == 1;
        delay_cycles == 0;
      };
      finish_item(item);
    end
  endtask : body

endclass : rv32e_alu_stress_seq

// Memory stress sequence
class rv32e_mem_stress_seq extends rv32e_base_sequence;

  rand int unsigned num_operations = 200;

  constraint c_num_operations {
    num_operations >= 50;
    num_operations <= 5000;
  }

  `uvm_object_utils(rv32e_mem_stress_seq)

  function new(string name = "rv32e_mem_stress_seq");
    super.new(name);
  endfunction : new

  task body();
    rv32e_seq_item item;

    // Randomize memory operations
    repeat (num_operations) begin
      item = rv32e_seq_item::type_id::create("item");
      start_item(item);
      item.randomize() with {
        is_load == 1;
        mem_addr[1:0] == 2'b00;
        mem_addr < 32'h00001000;  // Within IMEM range for data
      };
      finish_item(item);
    end
  endtask : body

endclass : rv32e_mem_stress_seq

// ============================================================================
// Corner Case Sequences
// ============================================================================

// Zero register sequence (edge case)
class rv32e_zero_reg_seq extends rv32e_base_sequence;

  `uvm_object_utils(rv32e_zero_reg_seq)

  function new(string name = "rv32e_zero_reg_seq");
    super.new(name);
  endfunction : new

  task body();
    rv32e_seq_item item;

    // Test operations with x0 (zero register)
    // ADD x0, x0, x0
    item = rv32e_seq_item::type_id::create("item");
    start_item(item);
    item.randomize() with {
      opcode == 7'b0110011;  // R-type
      rs1 == 0;
      rs2 == 0;
      rd == 0;
      alu_op == 4'd0;  // ADD
    };
    finish_item(item);

    // ADDI x0, x0, 0
    item = rv32e_seq_item::type_id::create("item");
    start_item(item);
    item.randomize() with {
      opcode == 7'b0010011;  // I-type
      rs1 == 0;
      rd == 0;
      alu_op == 4'd0;  // ADDI
      imm_i == 0;
    };
    finish_item(item);
  endtask : body

endclass : rv32e_zero_reg_seq

// All ones sequence
class rv32e_all_ones_seq extends rv32e_base_sequence;

  `uvm_object_utils(rv32e_all_ones_seq)

  function new(string name = "rv32e_all_ones_seq");
    super.new(name);
  endfunction : new

  task body();
    rv32e_seq_item item;

    // LUI with all ones
    item = rv32e_seq_item::type_id::create("item");
    start_item(item);
    item.randomize() with {
      opcode == 7'b0110111;  // LUI
      rd != 0;
      imm_u == 32'hFFFFFFFF;
    };
    finish_item(item);
  endtask : body

endclass : rv32e_all_ones_seq

// ============================================================================
// Error Injection Sequences
// ============================================================================

// Unaligned access sequence
class rv32e_unaligned_seq extends rv32e_base_sequence;

  `uvm_object_utils(rv32e_unaligned_seq)

  function new(string name = "rv32e_unaligned_seq");
    super.new(name);
  endfunction : new

  task body();
    rv32e_seq_item item;

    // Generate unaligned load/store operations
    repeat (5) begin
      item = rv32e_seq_item::type_id::create("item");
      start_item(item);
      item.randomize() with {
        is_load == 1;
        mem_addr[1:0] != 2'b00;  // Unaligned
      };
      finish_item(item);
    end
  endtask : body

endclass : rv32e_unaligned_seq

// Invalid CSR address sequence
class rv32e_invalid_csr_seq extends rv32e_base_sequence;

  `uvm_object_utils(rv32e_invalid_csr_seq)

  function new(string name = "rv32e_invalid_csr_seq");
    super.new(name);
  endfunction : new

  task body();
    rv32e_seq_item item;

    // Access non-existent CSR addresses
    repeat (5) begin
      item = rv32e_seq_item::type_id::create("item");
      start_item(item);
      item.randomize() with {
        is_csr == 1;
        csr_addr inside {12'h100, 12'h200, 12'h400, 12'h500};
      };
      finish_item(item);
    end
  endtask : body

endclass : rv32e_invalid_csr_seq

`endif // RV32E_SEQUENCE_LIB_SV
