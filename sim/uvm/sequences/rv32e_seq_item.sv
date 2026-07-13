`ifndef RV32E_SEQ_ITEM_SV
`define RV32E_SEQ_ITEM_SV

/**
 * RV32E instruction sequence item.
 * Models a single CPU instruction with fields for all instruction types.
 */
class rv32e_seq_item extends uvm_sequence_item;

  // Instruction fields
  rand bit [6:0]  opcode;
  rand bit [3:0]  rs1;
  rand bit [3:0]  rs2;
  rand bit [3:0]  rd;
  rand bit [2:0]  funct3;
  rand bit [6:0]  funct7;
  
  // Immediate values
  rand bit [31:0] imm_i;  // I-type immediate
  rand bit [31:0] imm_s;  // S-type immediate
  rand bit [31:0] imm_b;  // B-type immediate
  rand bit [31:0] imm_u;  // U-type immediate
  rand bit [31:0] imm_j;  // J-type immediate

  // Decoded instruction type
  rand bit        is_load;
  rand bit        is_store;
  rand bit        is_branch;
  rand bit        is_jal;
  rand bit        is_jalr;
  rand bit        is_lui;
  rand bit        is_auipc;
  rand bit        is_alu_i;  // I-type ALU
  rand bit        is_alu_r;  // R-type ALU
  rand bit        is_csr;
  rand bit        is_fence;
  rand bit        is_system;

  // ALU operation
  rand bit [3:0]  alu_op;
  
  // CSR fields
  rand bit [2:0]  csr_cmd;
  rand bit [11:0] csr_addr;
  rand bit        csr_imm;

  // Branch condition
  rand bit [2:0]  branch_cond;

  // Address and data for memory operations
  rand bit [31:0] mem_addr;
  rand bit [31:0] mem_wdata;
  rand bit [3:0]  mem_be;
  
  // Branch target
  rand bit [31:0] branch_target;

  // Execution results
  bit [31:0]      result;
  bit             reg_write;
  bit             mem_read;
  bit             mem_write;
  bit             commit;
  
  // Timing
  rand int unsigned delay_cycles;
  
  // Metadata
  string          instr_str;
  int             instr_id;
  static int      m_next_id = 0;

  // Constraints
  constraint c_opcode {
    opcode inside {7'b0110111,  // LUI
                   7'b0010111,  // AUIPC
                   7'b1101111,  // JAL
                   7'b1100111,  // JALR
                   7'b1100011,  // BEQ/BNE/BLT/BGE/BLTU/BGEU
                   7'b0000011,  // LB/LH/LW/LBU/LHU
                   7'b0100011,  // SB/SH/SW
                   7'b0010011,  // ADDI/SLLI/SRLI/SRAI/ANDI/ORI/XORI
                   7'b0110011,  // ADD/SUB/SLL/SLT/SLTU/XOR/SRL/SRA/OR/AND
                   7'b0001111,  // FENCE
                   7'b1110011}; // ECALL/EBREAK/MRET
  }

  constraint c_rs1_valid { rs1 <= 4'd15; }  // RV32E has 16 registers
  constraint c_rs2_valid { rs2 <= 4'd15; }
  constraint c_rd_valid  { rd  <= 4'd15; }

  constraint c_alu_op {
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

  constraint c_csr_addr {
    csr_addr inside {12'h300,  // MSTATUS
                     12'h304,  // MIE
                     12'h305,  // MTVEC
                     12'h341,  // MEPC
                     12'h342,  // MCAUSE
                     12'h344,  // MIP
                     12'hB00,  // MCYCLE
                     12'hB80}; // MCYCLEH
  }

  constraint c_branch_cond {
    branch_cond inside {3'd0,  // BEQ
                        3'd1,  // BNE
                        3'd4,  // BLT
                        3'd5,  // BGE
                        3'd6,  // BLTU
                        3'd7}; // BGEU
  }

  constraint c_mem_addr_aligned {
    mem_addr[1:0] == 2'b00;  // Word-aligned
  }

  constraint c_mem_be {
    mem_be != 4'b0000;  // At least one byte enabled
  }

  constraint c_delay {
    delay_cycles >= 0;
    delay_cycles <= 10;
  }

  //--------------------------------------------------------------------------
  // Constructor
  //--------------------------------------------------------------------------
  function new(string name = "rv32e_seq_item");
    super.new(name);
    instr_id = m_next_id++;
    delay_cycles = 0;
  endfunction : new

  //--------------------------------------------------------------------------
  // Utilities
  //--------------------------------------------------------------------------
  function string convert2string();
    string s;
    s = $sformatf("ID=%0d: opcode=0x%0x ", instr_id, opcode);
    s = {s, $sformatf("rs1=x%0d rs2=x%0d rd=x%0d ", rs1, rs2, rd)};
    
    if (is_load)      s = {s, "[LOAD] "};
    if (is_store)     s = {s, "[STORE] "};
    if (is_branch)    s = {s, "[BRANCH] "};
    if (is_jal)       s = {s, "[JAL] "};
    if (is_jalr)      s = {s, "[JALR] "};
    if (is_lui)       s = {s, "[LUI] "};
    if (is_auipc)     s = {s, "[AUIPC] "};
    if (is_csr)       s = {s, "[CSR] "};
    
    s = {s, $sformatf("result=0x%08x", result)};
    return s;
  endfunction : convert2string

  //--------------------------------------------------------------------------
  // copy() - Deep copy
  //--------------------------------------------------------------------------
  function void copy(uvm_sequence_item item);
    rv32e_seq_item rhs;
    
    if (!$cast(rhs, item)) begin
      `uvm_error("COPY_ERROR", "Invalid cast in rv32e_seq_item::copy()")
      return;
    end
    
    opcode        = rhs.opcode;
    rs1           = rhs.rs1;
    rs2           = rhs.rs2;
    rd            = rhs.rd;
    funct3        = rhs.funct3;
    funct7        = rhs.funct7;
    imm_i         = rhs.imm_i;
    imm_s         = rhs.imm_s;
    imm_b         = rhs.imm_b;
    imm_u         = rhs.imm_u;
    imm_j         = rhs.imm_j;
    is_load       = rhs.is_load;
    is_store      = rhs.is_store;
    is_branch     = rhs.is_branch;
    is_jal        = rhs.is_jal;
    is_jalr       = rhs.is_jalr;
    is_lui        = rhs.is_lui;
    is_auipc      = rhs.is_auipc;
    is_alu_i      = rhs.is_alu_i;
    is_alu_r      = rhs.is_alu_r;
    is_csr        = rhs.is_csr;
    is_fence      = rhs.is_fence;
    is_system     = rhs.is_system;
    alu_op        = rhs.alu_op;
    csr_cmd       = rhs.csr_cmd;
    csr_addr      = rhs.csr_addr;
    csr_imm       = rhs.csr_imm;
    branch_cond   = rhs.branch_cond;
    mem_addr      = rhs.mem_addr;
    mem_wdata     = rhs.mem_wdata;
    mem_be        = rhs.mem_be;
    branch_target = rhs.branch_target;
    result        = rhs.result;
    reg_write     = rhs.reg_write;
    mem_read      = rhs.mem_read;
    mem_write     = rhs.mem_write;
    commit        = rhs.commit;
    delay_cycles  = rhs.delay_cycles;
    instr_str     = rhs.instr_str;
    instr_id      = rhs.instr_id;
  endfunction : copy

  //--------------------------------------------------------------------------
  // compare() - Compare two items
  //--------------------------------------------------------------------------
  function bit compare(uvm_sequence_item item);
    rv32e_seq_item rhs;
    bit result;
    
    if (!$cast(rhs, item)) begin
      `uvm_error("COMPARE_ERROR", "Invalid cast in rv32e_seq_item::compare()")
      return 0;
    end
    
    result = (opcode        == rhs.opcode)        &&
             (rs1           == rhs.rs1)           &&
             (rs2           == rhs.rs2)           &&
             (rd            == rhs.rd)            &&
             (funct3        == rhs.funct3)        &&
             (funct7        == rhs.funct7)        &&
             (imm_i         == rhs.imm_i)         &&
             (imm_s         == rhs.imm_s)         &&
             (imm_b         == rhs.imm_b)         &&
             (imm_u         == rhs.imm_u)         &&
             (imm_j         == rhs.imm_j)         &&
             (is_load       == rhs.is_load)       &&
             (is_store      == rhs.is_store)      &&
             (is_branch     == rhs.is_branch)     &&
             (is_jal        == rhs.is_jal)        &&
             (is_jalr       == rhs.is_jalr)       &&
             (is_lui        == rhs.is_lui)        &&
             (is_auipc      == rhs.is_auipc)      &&
             (is_alu_i      == rhs.is_alu_i)      &&
             (is_alu_r      == rhs.is_alu_r)      &&
             (is_csr        == rhs.is_csr)        &&
             (is_fence      == rhs.is_fence)      &&
             (is_system     == rhs.is_system)     &&
             (alu_op        == rhs.alu_op)        &&
             (csr_cmd       == rhs.csr_cmd)       &&
             (csr_addr      == rhs.csr_addr)      &&
             (csr_imm       == rhs.csr_imm)       &&
             (branch_cond   == rhs.branch_cond)   &&
             (mem_addr      == rhs.mem_addr)      &&
             (mem_wdata     == rhs.mem_wdata)     &&
             (mem_be        == rhs.mem_be)        &&
             (branch_target == rhs.branch_target) &&
             (result        == rhs.result)        &&
             (reg_write     == rhs.reg_write)     &&
             (mem_read      == rhs.mem_read)      &&
             (mem_write     == rhs.mem_write)     &&
             (commit        == rhs.commit)        &&
             (delay_cycles  == rhs.delay_cycles)  &&
             (instr_str     == rhs.instr_str);
    
    return result;
  endfunction : compare

  //--------------------------------------------------------------------------
  // print() - Print item details
  //--------------------------------------------------------------------------
  function void print(uvm_printer printer = null);
    if (printer == null) begin
      uvm_default_printer = uvm_default_printer;
      super.print(printer);
    end else begin
      super.print(printer);
    end
  endfunction : print

  //--------------------------------------------------------------------------
  // pack/unpack
  //--------------------------------------------------------------------------
  function void pack_item(uvm_packer packer);
    super.pack_item(packer);
    packer.pack_field_int(opcode,      7, UVM_LITTLE_ENDIAN, 0);
    packer.pack_field_int(rs1,         4, UVM_LITTLE_ENDIAN, 0);
    packer.pack_field_int(rs2,         4, UVM_LITTLE_ENDIAN, 0);
    packer.pack_field_int(rd,          4, UVM_LITTLE_ENDIAN, 0);
    packer.pack_field_int(funct3,      3, UVM_LITTLE_ENDIAN, 0);
    packer.pack_field_int(funct7,      7, UVM_LITTLE_ENDIAN, 0);
    packer.pack_field_int(imm_i,      32, UVM_LITTLE_ENDIAN, 0);
    packer.pack_field_int(imm_s,      32, UVM_LITTLE_ENDIAN, 0);
    packer.pack_field_int(imm_b,      32, UVM_LITTLE_ENDIAN, 0);
    packer.pack_field_int(imm_u,      32, UVM_LITTLE_ENDIAN, 0);
    packer.pack_field_int(imm_j,      32, UVM_LITTLE_ENDIAN, 0);
    packer.pack_field_int(alu_op,      4, UVM_LITTLE_ENDIAN, 0);
    packer.pack_field_int(csr_cmd,     3, UVM_LITTLE_ENDIAN, 0);
    packer.pack_field_int(csr_addr,   12, UVM_LITTLE_ENDIAN, 0);
    packer.pack_field_int(branch_cond, 3, UVM_LITTLE_ENDIAN, 0);
    packer.pack_field_int(mem_addr,   32, UVM_LITTLE_ENDIAN, 0);
    packer.pack_field_int(mem_wdata,  32, UVM_LITTLE_ENDIAN, 0);
    packer.pack_field_int(mem_be,      4, UVM_LITTLE_ENDIAN, 0);
    packer.pack_field_int(branch_target, 32, UVM_LITTLE_ENDIAN, 0);
    packer.pack_field_int(result,     32, UVM_LITTLE_ENDIAN, 0);
    packer.pack_field_int(instr_id,   32, UVM_LITTLE_ENDIAN, 0);
  endfunction : pack_item

  function void unpack_item(uvm_packer packer);
    super.unpack_item(packer);
    opcode      = packer.unpack_field_int(7, UVM_LITTLE_ENDIAN, 0);
    rs1         = packer.unpack_field_int(4, UVM_LITTLE_ENDIAN, 0);
    rs2         = packer.unpack_field_int(4, UVM_LITTLE_ENDIAN, 0);
    rd          = packer.unpack_field_int(4, UVM_LITTLE_ENDIAN, 0);
    funct3      = packer.unpack_field_int(3, UVM_LITTLE_ENDIAN, 0);
    funct7      = packer.unpack_field_int(7, UVM_LITTLE_ENDIAN, 0);
    imm_i       = packer.unpack_field_int(32, UVM_LITTLE_ENDIAN, 0);
    imm_s       = packer.unpack_field_int(32, UVM_LITTLE_ENDIAN, 0);
    imm_b       = packer.unpack_field_int(32, UVM_LITTLE_ENDIAN, 0);
    imm_u       = packer.unpack_field_int(32, UVM_LITTLE_ENDIAN, 0);
    imm_j       = packer.unpack_field_int(32, UVM_LITTLE_ENDIAN, 0);
    alu_op      = packer.unpack_field_int(4, UVM_LITTLE_ENDIAN, 0);
    csr_cmd     = packer.unpack_field_int(3, UVM_LITTLE_ENDIAN, 0);
    csr_addr    = packer.unpack_field_int(12, UVM_LITTLE_ENDIAN, 0);
    branch_cond = packer.unpack_field_int(3, UVM_LITTLE_ENDIAN, 0);
    mem_addr    = packer.unpack_field_int(32, UVM_LITTLE_ENDIAN, 0);
    mem_wdata   = packer.unpack_field_int(32, UVM_LITTLE_ENDIAN, 0);
    mem_be      = packer.unpack_field_int(4, UVM_LITTLE_ENDIAN, 0);
    branch_target = packer.unpack_field_int(32, UVM_LITTLE_ENDIAN, 0);
    result      = packer.unpack_field_int(32, UVM_LITTLE_ENDIAN, 0);
    instr_id    = packer.unpack_field_int(32, UVM_LITTLE_ENDIAN, 0);
  endfunction : unpack_item

endclass : rv32e_seq_item

`endif // RV32E_SEQ_ITEM_SV
