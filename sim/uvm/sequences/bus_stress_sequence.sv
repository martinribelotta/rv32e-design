`ifndef BUS_STRESS_SEQUENCE_SV
`define BUS_STRESS_SEQUENCE_SV

/**
 * Bus Stress Sequence: Generates simultaneous IMEM fetch and DMEM write transactions
 * to trigger bus arbitration and wait state insertion.
 */
class bus_stress_sequence extends uvm_sequence#(rv32e_seq_item);
  `uvm_object_utils(bus_stress_sequence)

  // Number of stress cycles
  int num_stress_cycles = 20;
  
  // Probability of DMEM write during stress (0-100)
  int dmem_write_prob = 70;

  function new(string name = "bus_stress_sequence");
    super.new(name);
  endfunction : new

  task body();
    `uvm_info(get_name(), $sformatf("Starting bus stress sequence (%0d cycles, %0d%% DMEM writes)",
                                     num_stress_cycles, dmem_write_prob), UVM_MEDIUM)

    // Warm-up: execute a few normal instructions
    send_nop_sequence(3);

    // Stress phase: trigger bus conflicts
    for (int i = 0; i < num_stress_cycles; i++) begin
      // Randomly decide to do a DMEM write (which will conflict with IMEM fetch)
      if ($urandom_range(0, 99) < dmem_write_prob) begin
        // Emit a store instruction (e.g., sw x0, 0(x0))
        send_store_instruction(i);
      end else begin
        // Normal ALU instruction (no bus conflict)
        send_alu_instruction(i);
      end
    end

    // Cool-down: a few more instructions to observe pipeline recovery
    send_nop_sequence(3);

    `uvm_info(get_name(), "Bus stress sequence completed", UVM_MEDIUM)
  endtask : body

  // Helper: send NOP instructions (no memory accesses)
  task send_nop_sequence(int count);
    for (int i = 0; i < count; i++) begin
      rv32e_seq_item item;
      item = rv32e_seq_item::type_id::create($sformatf("nop_%0d", i));
      item.opcode = 7'b0010011;  // ADDI (ALU immediate)
      item.rd = 4'd0;            // x0 (discarded)
      item.rs1 = 4'd0;
      item.imm = 12'd0;
      assert(item.randomize() with { rd == 4'd0; });
      start_item(item);
      finish_item(item);
    end
  endtask : send_nop_sequence

  // Helper: send a store instruction (triggers DMEM write, bus contention)
  task send_store_instruction(int seq_num);
    rv32e_seq_item item;
    item = rv32e_seq_item::type_id::create($sformatf("store_%0d", seq_num));
    // Instruction: sw x1, 0(x2)  →  store word at address [x2]
    item.opcode = 7'b0100011;  // S-type (store)
    item.funct3 = 3'b010;      // sw (word)
    item.rd = 4'd0;            // unused for stores
    item.rs1 = 4'd2;           // base address register
    item.rs2 = 4'd1;           // value to store
    item.imm = 12'd0;          // offset = 0
    assert(item.randomize(false));  // keep explicitly set fields
    start_item(item);
    finish_item(item);
  endtask : send_store_instruction

  // Helper: send an ALU instruction (no bus conflict)
  task send_alu_instruction(int seq_num);
    rv32e_seq_item item;
    item = rv32e_seq_item::type_id::create($sformatf("alu_%0d", seq_num));
    // Randomized ALU instruction (add, sub, and, or, etc.)
    assert(item.randomize() with {
      opcode inside {7'b0110011, 7'b0010011};  // R-type or I-type ALU
      rd != 4'd0;                               // avoid x0
      rs1 != 4'd0;
      rs2 != 4'd0;
    });
    start_item(item);
    finish_item(item);
  endtask : send_alu_instruction

endclass : bus_stress_sequence

/**
 * Bus Arbitration Priority Test Sequence:
 * Verifies that DMEM writes have priority over IMEM fetch.
 */
class bus_priority_sequence extends uvm_sequence#(rv32e_seq_item);
  `uvm_object_utils(bus_priority_sequence)

  function new(string name = "bus_priority_sequence");
    super.new(name);
  endfunction : new

  task body();
    `uvm_info(get_name(), "Starting bus priority test sequence", UVM_MEDIUM)

    // Scenario: alternating DMEM writes and IMEM fetches
    // Expected: DMEM always granted, IMEM stalled

    for (int i = 0; i < 10; i++) begin
      rv32e_seq_item item = rv32e_seq_item::type_id::create($sformatf("priority_store_%0d", i));
      item.opcode = 7'b0100011;  // S-type
      item.funct3 = 3'b010;
      item.rs1 = 4'd2;
      item.rs2 = 4'd1;
      item.imm = 12'd0;
      assert(item.randomize(false));
      start_item(item);
      finish_item(item);
    end

    `uvm_info(get_name(), "Bus priority test sequence completed", UVM_MEDIUM)
  endtask : body

endclass : bus_priority_sequence

/**
 * Consecutive Conflicts Sequence:
 * Tests behavior when bus conflicts occur back-to-back.
 */
class bus_consecutive_conflicts_sequence extends uvm_sequence#(rv32e_seq_item);
  `uvm_object_utils(bus_consecutive_conflicts_sequence)

  function new(string name = "bus_consecutive_conflicts_sequence");
    super.new(name);
  endfunction : new

  task body();
    `uvm_info(get_name(), "Starting consecutive conflicts sequence", UVM_MEDIUM)

    // Emit 5 consecutive store instructions (maximum bus conflict)
    for (int i = 0; i < 5; i++) begin
      rv32e_seq_item item = rv32e_seq_item::type_id::create($sformatf("conflict_%0d", i));
      item.opcode = 7'b0100011;  // S-type
      item.funct3 = 3'b010;
      item.rs1 = 4'd2;
      item.rs2 = 4'd1;
      item.imm = 12'h800 + (i << 2);  // different addresses
      assert(item.randomize(false));
      start_item(item);
      finish_item(item);
    end

    // Interleave with ALU instructions (no conflicts)
    for (int i = 0; i < 5; i++) begin
      rv32e_seq_item item = rv32e_seq_item::type_id::create($sformatf("recovery_%0d", i));
      assert(item.randomize() with {
        opcode inside {7'b0110011, 7'b0010011};
        rd != 4'd0;
      });
      start_item(item);
      finish_item(item);
    end

    `uvm_info(get_name(), "Consecutive conflicts sequence completed", UVM_MEDIUM)
  endtask : body

endclass : bus_consecutive_conflicts_sequence

`endif // BUS_STRESS_SEQUENCE_SV
