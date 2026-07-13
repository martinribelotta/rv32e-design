`ifndef RV32E_ASSERTIONS_SV
`define RV32E_ASSERTIONS_SV

/**
 * RV32E SVA Assertions.
 * Protocol, timing, reset, FIFO, handshakes, and critical property checks.
 */

// ============================================================================
// CPU Interface Assertions
// ============================================================================

// CPU interface assertions module
module rv32e_cpu_assertions (
    input clk,
    input rst_n,
    
    // IF stage
    input        if_valid,
    input [31:0] if_pc,
    input [31:0] if_instr,
    
    // ID/EX stage
    input        id_valid,
    input [6:0]  id_opcode,
    input [3:0]  id_rs1,
    input [3:0]  id_rs2,
    input [3:0]  id_rd,
    input [2:0]  id_funct3,
    input [6:0]  id_funct7,
    input [31:0] id_imm,
    
    // MEM/WB stage
    input        mem_valid,
    input [31:0] mem_result,
    input [31:0] mem_addr,
    input [3:0]  mem_be,
    input        mem_read,
    input        mem_write,
    
    // WB stage
    input        wb_valid,
    input [31:0] wb_result,
    input [3:0]  wb_rd,
    input        wb_reg_write,
    
    // Control signals
    input        branch_taken,
    input        jal,
    input        jalr,
    input        is_load,
    input        is_store,
    input        is_csr,
    
    // CSR
    input [11:0] csr_addr,
    input [2:0]  csr_cmd,
    input        csr_imm,
    
    // Pipeline registers
    input [31:0] if_id_pc,
    input [31:0] if_id_instr,
    input        if_id_valid,
    
    // Interrupts
    input        irq,
    input        timer_irq,
    
    // Memory interface
    input [31:0] dmem_rdata,
    
    // Status
    input        stall,
    input        flush_pending
);

  // ============================================================================
  // Reset Assertions
  // ============================================================================
  
  // Assert reset when rst_n is low
  a_reset_asserted : assert property (
    @(posedge clk) disable iff (!rst_n)
      rst_n == 0
  ) else 
    $error("RESET: rst_n should be low during reset");
  
  // Deassert reset after reset period
  a_reset_deasserted : assert property (
    @(posedge clk) 
      rst_n === 1
  ) else 
    $error("RESET: rst_n should be high after reset period");
  
  // PC should be 0 after reset
  a_pc_zero_after_reset : assert property (
    @(posedge clk) ($rose(!rst_n) |=> pc == 32'h0)
  ) else 
    $error("RESET: PC should be 0 after reset");
  
  // ============================================================================
  // Pipeline Assertions
  // ============================================================================
  
  // IF stage valid signal
  a_if_valid_1cycle : assert property (
    @(posedge clk) disable iff (!rst_n)
      $rose(if_valid) |=> if_valid throughout (##[1:1] if_valid)
  ) else 
    $error("PIPELINE: IF stage should stay valid for 1 cycle");
  
  // ID/EX stage propagation
  a_id_valid_after_if : assert property (
    @(posedge clk) disable iff (!rst_n)
      $rose(if_valid) |=> ##1 id_valid
  ) else 
    $error("PIPELINE: ID stage should follow IF stage");
  
  // MEM/WB stage propagation
  a_mem_valid_after_id : assert property (
    @(posedge clk) disable iff (!rst_n)
      $rose(id_valid) |=> ##1 mem_valid
  ) else 
    $error("PIPELINE: MEM stage should follow ID stage");
  
  // WB stage propagation
  a_wb_valid_after_mem : assert property (
    @(posedge clk) disable iff (!rst_n)
      $rose(mem_valid) |=> ##1 wb_valid
  ) else 
    $error("PIPELINE: WB stage should follow MEM stage");
  
  // ============================================================================
  // Instruction Format Assertions
  // ============================================================================
  
  // R-type instruction format
  a_r_type_format : assert property (
    @(posedge clk) disable iff (!rst_n)
      (id_opcode == 7'b0110011) |-> 
      id_funct7 == 7'b0000000 || id_funct7 == 7'b0100000
  ) else 
    $error("FORMAT: Invalid R-type format");
  
  // I-type instruction format
  a_i_type_format : assert property (
    @(posedge clk) disable iff (!rst_n)
      (id_opcode == 7'b0000011 || id_opcode == 7'b0010011) |-> 
      id_funct3 inside {3'b000, 3'b010, 3'b011, 3'b100, 3'b110, 3'b111}
  ) else 
    $error("FORMAT: Invalid I-type format");
  
  // S-type instruction format
  a_s_type_format : assert property (
    @(posedge clk) disable iff (!rst_n)
      (id_opcode == 7'b0100011) |-> 
      id_funct3 inside {3'b000, 3'b010, 3'b011}
  ) else 
    $error("FORMAT: Invalid S-type format");
  
  // B-type instruction format
  a_b_type_format : assert property (
    @(posedge clk) disable iff (!rst_n)
      (id_opcode == 7'b1100011) |-> 
      id_funct3 inside {3'b000, 3'b001, 3'b100, 3'b101, 3'b110, 3'b111}
  ) else 
    $error("FORMAT: Invalid B-type format");
  
  // ============================================================================
  // Load/Store Assertions
  // ============================================================================
  
  // Load address alignment
  a_load_aligned : assert property (
    @(posedge clk) disable iff (!rst_n)
      (is_load && mem_valid) |-> mem_addr[1:0] == 2'b00
  ) else 
    $error("MEMORY: Load address must be word-aligned");
  
  // Store address alignment
  a_store_aligned : assert property (
    @(posedge clk) disable iff (!rst_n)
      (is_store && mem_valid) |-> mem_addr[1:0] == 2'b00
  ) else 
    $error("MEMORY: Store address must be word-aligned");
  
  // Store byte enable not zero
  a_store_be_not_zero : assert property (
    @(posedge clk) disable iff (!rst_n)
      (is_store && mem_valid) |-> mem_be != 4'b0000
  ) else 
    $error("MEMORY: Store byte enable must not be zero");
  
  // Load data valid after MEM stage
  a_load_data_valid : assert property (
    @(posedge clk) disable iff (!rst_n)
      (is_load && mem_valid) |=> dmem_rdata !== 32'xxxxxxxx
  ) else 
    $error("MEMORY: Load data should be valid after MEM stage");
  
  // ============================================================================
  // Branch Assertions
  // ============================================================================
  
  // Branch target alignment
  a_branch_target_aligned : assert property (
    @(posedge clk) disable iff (!rst_n)
      (branch_taken && mem_valid) |-> mem_result[1:0] == 2'b00
  ) else 
    $error("BRANCH: Branch target must be word-aligned");
  
  // Branch in ID/EX stage
  a_branch_in_id : assert property (
    @(posedge clk) disable iff (!rst_n)
      $rose(branch_taken) |=> id_valid && !mem_valid
  ) else 
    $error("BRANCH: Branch should be resolved in ID/EX stage");
  
  // ============================================================================
  // Jump Assertions
  // ============================================================================
  
  // JAL target alignment
  a_jal_target_aligned : assert property (
    @(posedge clk) disable iff (!rst_n)
      (jal && mem_valid) |-> mem_result[1:0] == 2'b00
  ) else 
    $error("JUMP: JAL target must be word-aligned");
  
  // JALR target alignment
  a_jalr_target_aligned : assert property (
    @(posedge clk) disable iff (!rst_n)
      (jalr && mem_valid) |-> mem_result[1:0] == 2'b00
  ) else 
    $error("JUMP: JALR target must be word-aligned");
  
  // ============================================================================
  // CSR Assertions
  // ============================================================================
  
  // CSR address valid range
  a_csr_addr_valid : assert property (
    @(posedge clk) disable iff (!rst_n)
      (is_csr && id_valid) |-> csr_addr inside {
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
      }
  ) else 
    $error("CSR: Invalid CSR address");
  
  // CSR command valid
  a_csr_cmd_valid : assert property (
    @(posedge clk) disable iff (!rst_n)
      (is_csr && id_valid) |-> csr_cmd inside {3'd1, 3'd2, 3'd3, 3'd5, 3'd6, 3'd7}
  ) else 
    $error("CSR: Invalid CSR command");
  
  // CSR write to x0 disabled
  a_csr_no_write_x0 : assert property (
    @(posedge clk) disable iff (!rst_n)
      (is_csr && id_valid && wb_rd == 0) |-> wb_reg_write == 0
  ) else 
    $error("CSR: CSR write should not write to x0");
  
  // ============================================================================
  // Interrupt Assertions
  // ============================================================================
  
  // Interrupt only when MIE is set
  a_interrupt_mie : assert property (
    @(posedge clk) disable iff (!rst_n)
      irq |-> mstatus_mie == 1'b1
  ) else 
    $error("INTERRUPT: Interrupt only when MIE is set");
  
  // Timer interrupt timing
  a_timer_irq_timing : assert property (
    @(posedge clk) disable iff (!rst_n)
      $rose(timer_irq) |=> mcause == 32'h80000007
  ) else 
    $error("INTERRUPT: Timer interrupt should set mcause to 7");
  
  // External interrupt timing
  a_external_irq_timing : assert property (
    @(posedge clk) disable iff (!rst_n)
      $rose(irq) |=> mcause == 32'h8000000B
  ) else 
    $error("INTERRUPT: External interrupt should set mcause to 11");
  
  // ============================================================================
  // Stall and Flush Assertions
  // ============================================================================
  
  // Stall during load-use hazard
  a_stall_load_use : assert property (
    @(posedge clk) disable iff (!rst_n)
      (stall && mem_valid) |-> is_load
  ) else 
    $error("STALL: Stall should only occur for load-use hazard");
  
  // Flush during control transfer
  a_flush_control_transfer : assert property (
    @(posedge clk) disable iff (!rst_n)
      (flush_pending && id_valid) |-> 
      (branch_taken || jal || jalr)
  ) else 
    $error("FLUSH: Flush should only occur during control transfer");
  
  // ============================================================================
  // Memory Interface Assertions
  // ============================================================================
  
  // Memory request valid
  a_mem_req_valid : assert property (
    @(posedge clk) disable iff (!rst_n)
      (mem_read || mem_write) |-> mem_valid
  ) else 
    $error("MEMORY: Memory request should be valid");
  
  // Memory read data ready
  a_mem_read_ready : assert property (
    @(posedge clk) disable iff (!rst_n)
      mem_read |=> dmem_rdata !== 32'xxxxxxxx
  ) else 
    $error("MEMORY: Read data should be ready");
  
  // ============================================================================
  // Register File Assertions
  // ============================================================================
  
  // Register address in range
  a_reg_addr_range : assert property (
    @(posedge clk) disable iff (!rst_n)
      id_rs1 <= 4'd15 && id_rs2 <= 4'd15 && id_rd <= 4'd15
  ) else 
    $error("REGFILE: Register address out of range (RV32E has 16 registers)");
  
  // Write to x0 should not occur
  a_write_x0 : assert property (
    @(posedge clk) disable iff (!rst_n)
      wb_valid && wb_reg_write |-> wb_rd != 0
  ) else 
    $error("REGFILE: Write to x0 should not occur");
  
  // ============================================================================
  // Control Flow Assertions
  // ============================================================================
  
  // PC increment
  a_pc_increment : assert property (
    @(posedge clk) disable iff (!rst_n)
      $stable(if_pc) || $change(if_pc) |=> if_pc == prev(if_pc) + 4
  ) else 
    $error("CONTROL: PC should increment by 4 for sequential instructions");
  
  // No instruction during flush
  a_no_instr_during_flush : assert property (
    @(posedge clk) disable iff (!rst_n)
      flush_pending |=> !if_valid
  ) else 
    $error("CONTROL: No instruction during flush");
  
  // ============================================================================
  // Timeout Assertions
  // ============================================================================
  
  // Progress check - PC should change within N cycles
  a_progress_check : assert property (
    @(posedge clk) disable iff (!rst_n)
      disable iff (!if_valid)
      $stable(if_pc) throughout (##[0:100] $change(if_pc))
  ) else 
    $error("TIMEOUT: PC should change within 100 cycles (possible deadlock)");
  
  // ============================================================================
  // FIFO Assertions
  // ============================================================================
  
  // IF stage FIFO should not overflow
  a_if_fifo_overflow : assert property (
    @(posedge clk) disable iff (!rst_n)
      if_valid |=> $stable(if_valid) |=> ##1 $change(if_pc)
  ) else 
    $error("FIFO: IF stage overflow detected");
  
  // Pipeline register integrity
  a_pipeline_reg_integrity : assert property (
    @(posedge clk) disable iff (!rst_n)
      if_valid |=> 
      ##1 id_opcode == if_id_instr[6:0] &&
      ##1 id_rs1 == if_id_instr[18:15] &&
      ##1 id_rs2 == if_id_instr[23:20] &&
      ##1 id_rd == if_id_instr[10:7]
  ) else 
    $error("FIFO: Pipeline register integrity violation");

endmodule : rv32e_cpu_assertions

// ============================================================================
// Memory Interface Assertions
// ============================================================================

module rv32e_memory_assertions (
    input clk,
    input rst_n,
    
    // IMEM interface
    input        imem_valid,
    input [31:0] imem_addr,
    input [31:0] imem_rdata,
    
    // DMEM interface
    input        dmem_valid,
    input [31:0] dmem_addr,
    input [31:0] dmem_wdata,
    input [3:0]  dmem_we,
    input [31:0] dmem_rdata,
    
    // Control signals
    input        imem_read,
    input        dmem_read,
    input        dmem_write
);

  // ============================================================================
  // Address Space Assertions
  // ============================================================================
  
  // IMEM address range (0x0000 - 0x0FFF)
  a_imem_addr_range : assert property (
    @(posedge clk) disable iff (!rst_n)
      (imem_valid && imem_read) |-> imem_addr[15:12] == 4'h0
  ) else 
    $error("IMEM: Address out of range (should be 0x0000-0x0FFF)");
  
  // DMEM address range (0x1000 - 0x1EFF)
  a_dmem_addr_range : assert property (
    @(posedge clk) disable iff (!rst_n)
      (dmem_valid && (dmem_read || dmem_write)) |-> 
      dmem_addr[15:12] inside {4'h1, 4'h0}
  ) else 
    $error("DMEM: Address out of range (should be 0x1000-0x1EFF)");
  
  // ============================================================================
  // Read-before-Write Semantics
  // ============================================================================
  
  // Read returns old value during simultaneous read/write
  a_read_before_write : assert property (
    @(posedge clk) disable iff (!rst_n)
      (dmem_valid && dmem_read && dmem_write && dmem_addr == prev(dmem_addr)) |=> 
      dmem_rdata == prev(dmem_rdata)
  ) else 
    $error("MEMORY: Read-before-write should return old value");
  
  // ============================================================================
  // Byte Enable Assertions
  // ============================================================================
  
  // Byte enable not zero for writes
  a_be_not_zero : assert property (
    @(posedge clk) disable iff (!rst_n)
      (dmem_valid && dmem_write) |-> dmem_we != 4'b0000
  ) else 
    $error("MEMORY: Byte enable must not be zero for write");
  
  // ============================================================================
  // Latency Assertions
  // ============================================================================
  
  // IMEM 1-cycle latency
  a_imem_latency : assert property (
    @(posedge clk) disable iff (!rst_n)
      $rose(imem_valid) |=> ##1 imem_rdata !== 32'xxxxxxxx
  ) else 
    $error("MEMORY: IMEM should have 1-cycle latency");
  
  // DMEM 1-cycle latency
  a_dmem_latency : assert property (
    @(posedge clk) disable iff (!rst_n)
      $rose(dmem_valid) |=> ##1 dmem_rdata !== 32'xxxxxxxx
  ) else 
    $error("MEMORY: DMEM should have 1-cycle latency");

endmodule : rv32e_memory_assertions

// ============================================================================
// CSR Interface Assertions
// ============================================================================

module rv32e_csr_assertions (
    input clk,
    input rst_n,
    
    // CSR interface
    input        csr_valid,
    input [11:0] csr_addr,
    input [31:0] csr_wdata,
    input [31:0] csr_rdata,
    input [2:0]  csr_cmd,
    
    // Control signals
    input        csr_read,
    input        csr_write,
    
    // CPU state
    input [31:0] mstatus,
    input [31:0] mie,
    input [31:0] mip,
    input [31:0] mtvec,
    input [31:0] mepc,
    input [31:0] mcause
);

  // ============================================================================
  // CSR Address Space Assertions
  // ============================================================================
  
  // Valid CSR address range
  a_csr_addr_valid_space : assert property (
    @(posedge clk) disable iff (!rst_n)
      (csr_valid && csr_read) |-> csr_addr[11:8] == 4'h3 || csr_addr[11:8] == 4'hB
  ) else 
    $error("CSR: Invalid CSR address space (should be 0x3xx or 0xBxx)");
  
  // ============================================================================
  // CSR Operation Assertions
  // ============================================================================
  
  // CSRRW (write) operation
  a_csrrw_op : assert property (
    @(posedge clk) disable iff (!rst_n)
      (csr_valid && csr_cmd == 3'd1) |-> csr_write
  ) else 
    $error("CSR: CSRRW should perform write");
  
  // CSRRS (set) operation
  a_csrrs_op : assert property (
    @(posedge clk) disable iff (!rst_n)
      (csr_valid && csr_cmd == 3'd2) |-> csr_read
  ) else 
    $error("CSR: CSRRS should perform read");
  
  // CSRRC (clear) operation
  a_csrrc_op : assert property (
    @(posedge clk) disable iff (!rst_n)
      (csr_valid && csr_cmd == 3'd3) |-> csr_read
  ) else 
    $error("CSR: CSRRC should perform read");
  
  // ============================================================================
  // MSTATUS Assertions
  // ============================================================================
  
  // MSTATUS MIE bit only in privileged mode
  a_mstatus_mie_privileged : assert property (
    @(posedge clk) disable iff (!rst_n)
      (csr_addr == 12'h300 && csr_write) |-> 
      mstatus[31] == 1'b1  // MPP should be machine mode
  ) else 
    $error("CSR: MSTATUS write only allowed in machine mode");
  
  // MSTATUS MIE is read-only in user mode
  a_mstatus_mie_readonly_user : assert property (
    @(posedge clk) disable iff (!rst_n)
      (csr_addr == 12'h300 && csr_write && mstatus[31] == 1'b0) |-> 
      csr_wdata[7] == mstatus[7]
  ) else 
    $error("CSR: MSTATUS.MIE is read-only in user mode");
  
  // ============================================================================
  // MIE Assertions
  // ============================================================================
  
  // MTIE bit (machine timer interrupt enable)
  a_mie_mt ie : assert property (
    @(posedge clk) disable iff (!rst_n)
      (csr_addr == 12'h304 && csr_write) |-> 
      csr_wdata[7] == mie[7]  // MTIE at bit 7
  ) else 
    $error("CSR: MIE.MTIE write failed");
  
  // MEIE bit (machine external interrupt enable)
  a_mie_meie : assert property (
    @(posedge clk) disable iff (!rst_n)
      (csr_addr == 12'h304 && csr_write) |-> 
      csr_wdata[11] == mie[11]  // MEIE at bit 11
  ) else 
    $error("CSR: MIE.MEIE write failed");
  
  // ============================================================================
  // MTVEC Assertions
  // ============================================================================
  
  // MTVEC base address aligned
  a_mtvec_base_aligned : assert property (
    @(posedge clk) disable iff (!rst_n)
      (csr_addr == 12'h305 && csr_write) |-> 
      csr_wdata[1:0] == 2'b00  // Base address aligned
  ) else 
    $error("CSR: MTVEC base address must be word-aligned");
  
  // ============================================================================
  // MEPC Assertions
  // ============================================================================
  
  // MEPC address aligned
  a_mepc_aligned : assert property (
    @(posedge clk) disable iff (!rst_n)
      (csr_addr == 12'h341 && csr_write) |-> 
      csr_wdata[1:0] == 2'b00  // Address aligned
  ) else 
    $error("CSR: MEPC must be word-aligned");
  
  // ============================================================================
  // MCAUSE Assertions
  // ============================================================================
  
  // MCAUSE interrupt bit setting
  a_mcause_interrupt : assert property (
    @(posedge clk) disable iff (!rst_n)
      (csr_addr == 12'h342 && csr_write) |-> 
      csr_wdata[31] == 1'b1  // Interrupt bit set for interrupts
  ) else 
    $error("CSR: MCAUSE interrupt bit must be set for interrupts");
  
  // ============================================================================
  // MIP Assertions
  // ============================================================================
  
  // MIP is read-only for software
  a_mip_readonly : assert property (
    @(posedge clk) disable iff (!rst_n)
      (csr_addr == 12'h344 && csr_write) |-> 
      csr_wdata == 32'h0  // Writing MIP should have no effect
  ) else 
    $error("CSR: MIP is read-only for software");

endmodule : rv32e_csr_assertions

// ============================================================================
// Pipeline Hazard Assertions
// ============================================================================

module rv32e_hazard_assertions (
    input clk,
    input rst_n,
    
    // Pipeline stages
    input        if_valid,
    input        id_valid,
    input        mem_valid,
    input        wb_valid,
    
    // Hazard signals
    input        load_use_stall,
    input        branch_mispredict,
    input        control_stall,
    
    // Register file
    input [3:0]  rs1,
    input [3:0]  rs2,
    input [3:0]  rd,
    
    // Memory operations
    input        mem_read,
    input        mem_write,
    input [3:0]  mem_be
);

  // ============================================================================
  // Load-Use Hazard Assertions
  // ============================================================================
  
  // Load-use hazard should stall
  a_load_use_stall : assert property (
    @(posedge clk) disable iff (!rst_n)
      (mem_read && wb_valid && (rs1 == prev(wb_rd) || rs2 == prev(wb_rd))) |=> 
      load_use_stall
  ) else 
    $error("HAZARD: Load-use hazard should cause stall");
  
  // Stalled PC should not advance
  a_stalled_pc : assert property (
    @(posedge clk) disable iff (!rst_n)
      load_use_stall |=> $stable(if_valid) |=> $stable(id_valid)
  ) else 
    $error("HAZARD: PC should not advance during stall");
  
  // ============================================================================
  // Branch Hazard Assertions
  // ============================================================================
  
  // Branch resolution in ID/EX stage
  a_branch_resolve_id : assert property (
    @(posedge clk) disable iff (!rst_n)
      $rose(id_valid && control_stall) |=> 
      (mem_valid && !wb_valid)  // Resolve in ID/EX
  ) else 
    $error("HAZARD: Branch should resolve in ID/EX stage");
  
  // Branch misprediction flush
  a_branch_flush : assert property (
    @(posedge clk) disable iff (!rst_n)
      branch_mispredict |=> !id_valid  // Flush ID stage
  ) else 
    $error("HAZARD: Branch misprediction should flush pipeline");
  
  // ============================================================================
  // Forwarding Assertions
  // ============================================================================
  
  // EX/MEM forwarding available
  a_ex_mem_forward : assert property (
    @(posedge clk) disable iff (!rst_n)
      (mem_valid && wb_valid && rd == prev(wb_rd)) |-> 
      alu_result == prev(mem_result)
  ) else 
    $error("FORWARD: EX/MEM forwarding should provide correct result");
  
  // MEM/WB forwarding available
  a_mem_wb_forward : assert property (
    @(posedge clk) disable iff (!rst_n)
      (wb_valid && rd == prev(wb_rd)) |-> 
      alu_result == prev(wb_result)
  ) else 
    $error("FORWARD: MEM/WB forwarding should provide correct result");

endmodule : rv32e_hazard_assertions

`endif // RV32E_ASSERTIONS_SV
