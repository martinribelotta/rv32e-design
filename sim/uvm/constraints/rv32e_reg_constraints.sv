`ifndef RV32E_REG_CONSTRAINTS_SV
`define RV32E_REG_CONSTRAINTS_SV

/**
 * Register constraints for RV32E.
 * Defines constraints for register files and CSRs.
 */
class rv32e_reg_constraints;

  // Register file constraints
  constraint c_reg_file {
    // All 16 registers in RV32E
    foreach (m_registers[i]) {
      m_registers[i] inside {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15};
    }
  }

  // CSR address constraints
  constraint c_csr_addresses {
    csr_addr inside {
      12'h300,  // MSTATUS
      12'h301,  // MISA
      12'h304,  // MIE
      12'h305,  // MTVEC
      12'h340,  // MSCRATCH
      12'h341,  // MEPC
      12'h342,  // MCAUSE
      12'h343,  // MTVAL
      12'h344,  // MIP
      12'hB00,  // MCYCLE
      12'hB02,  // MINSTRET
      12'hB80,  // MCYCLEH
      12'hB82   // MINSTRETH
    };
  }

  // CSR command constraints
  constraint c_csr_commands {
    csr_cmd inside {3'd1,  // CSRRW
                    3'd2,  // CSRRS
                    3'd3,  // CSRRC
                    3'd5,  // CSRRWZ
                    3'd6,  // CSRRSI
                    3'd7}; // CSRRCI
  }

  // Branch condition constraints
  constraint c_branch_conditions {
    branch_cond inside {3'd0,  // BEQ
                        3'd1,  // BNE
                        3'd4,  // BLT
                        3'd5,  // BGE
                        3'd6,  // BLTU
                        3'd7}; // BGEU
  }

  // ALU operation constraints
  constraint c_alu_operations {
    alu_op inside {4'd0,  // ADD
                   4'd1,  // SUB
                   4'd2,  // SLL
                   4'd3,  // SLT
                   4'd4,  // SLTU
                   4'd5,  // XOR
                   4'd6,  // SRL
                   4'd7,  // SRA
                   4'd8,  // OR
                   4'd9,  // AND
                   4'd10}; // PASS
  }

  // Memory operation constraints
  constraint c_mem_operations {
    // Address must be word-aligned
    mem_addr[1:0] == 2'b00;
    
    // Byte enable must have at least one bit set for writes
    if (is_store) {
      mem_be != 4'b0000;
    }
  }

  // Random instruction type constraints
  constraint c_instruction_types {
    // Probabilistic distribution
    is_alu_i      dist {1 := 40, 0 := 60};
    is_alu_r      dist {1 := 30, 0 := 70};
    is_load       dist {1 := 15, 0 := 85};
    is_store      dist {1 := 10, 0 := 90};
    is_branch     dist {1 := 10, 0 := 90};
    is_jal        dist {1 := 5,  0 := 95};
    is_jalr       dist {1 := 5,  0 := 95};
    is_lui        dist {1 := 5,  0 := 95};
    is_auipc      dist {1 := 3,  0 := 97};
    is_csr        dist {1 := 5,  0 := 95};
    is_fence      dist {1 := 1,  0 := 99};
    is_system     dist {1 := 2,  0 := 98};
  }

  // Edge case constraints (for corner case testing)
  class edge_cases_c;
    // Zero register constraints
    constraint c_zero_reg {
      rs1 == 0;
      rd == 0;
    }

    // All ones immediate
    constraint c_all_ones_imm {
      imm_i == 32'hFFFFFFFF;
      imm_s == 32'hFFFFFFFF;
    }

    // Maximum values
    constraint c_max_values {
      rs1 == 4'd15;
      rs2 == 4'd15;
      rd == 4'd15;
    }

    // Boundary addresses
    constraint c_boundary_addr {
      mem_addr inside {32'h00000000, 32'hFFFFFC00, 32'h00001000};
    }
  endclass

endclass : rv32e_reg_constraints

`endif // RV32E_REG_CONSTRAINTS_SV
