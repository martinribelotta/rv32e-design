`ifndef RV32E_PREDICTOR_SV
`define RV32E_PREDICTOR_SV

/**
 * RV32E Reference Model (Predictor).
 * Models the expected behavior of the RV32E CPU.
 */
class rv32e_predictor extends uvm_component;

  // Analysis exports
  uvm_analysis_export#(rv32e_seq_item) cpu_instr_analysis_export;
  uvm_analysis_export#(rv32e_mem_op)   imem_analysis_export;
  uvm_analysis_export#(rv32e_mem_op)   dmem_analysis_export;

  // Analysis port
  uvm_analysis_port#(rv32e_check_result) analysis_export;

  // CPU state
  bit [31:0] m_pc;
  bit [3:0]  m_registers[16];  // RV32E has 16 registers
  bit        m_mstatus_mie;
  bit [31:0] m_mip;
  bit [31:0] m_mie;
  bit [31:0] m_mtvec;
  bit [31:0] m_mepc;
  bit [31:0] m_mcause;

  // Memory models
  rv32e_dmem_model m_dmem;

  // Pending operations
  typedef struct {
    rv32e_seq_item item;
    int            cycle;
  } pending_op_t;

  pending_op_t m_pending_ops[$];

  // Statistics
  int m_total_instructions = 0;
  int m_alu_instructions = 0;
  int m_load_instructions = 0;
  int m_store_instructions = 0;
  int m_branch_instructions = 0;
  int m_jump_instructions = 0;
  int m_csr_instructions = 0;

  // TLM FIFOs
  uvm_tlm_analysis_fifo#(rv32e_seq_item) m_cpu_instr_fifo;
  uvm_tlm_analysis_fifo#(rv32e_mem_op)   m_imem_fifo;
  uvm_tlm_analysis_fifo#(rv32e_mem_op)   m_dmem_fifo;

  `uvm_component_utils_begin(rv32e_predictor)
    `uvm_field_int(m_total_instructions, UVM_DEFAULT)
    `uvm_field_int(m_alu_instructions, UVM_DEFAULT)
    `uvm_field_int(m_load_instructions, UVM_DEFAULT)
    `uvm_field_int(m_store_instructions, UVM_DEFAULT)
    `uvm_field_int(m_branch_instructions, UVM_DEFAULT)
    `uvm_field_int(m_jump_instructions, UVM_DEFAULT)
    `uvm_field_int(m_csr_instructions, UVM_DEFAULT)
  `uvm_component_utils_end

  //--------------------------------------------------------------------------
  // Constructor
  //--------------------------------------------------------------------------
  function new(string name = "rv32e_predictor", uvm_component parent = null);
    super.new(name, parent);
    m_pc = 32'h0;
    for (int i = 0; i < 16; i++) m_registers[i] = 32'h0;
    m_mstatus_mie = 1'b1;
    m_mip = 32'h0;
    m_mie = 32'h0;
    m_mtvec = 32'h0;
    m_mepc = 32'h0;
    m_mcause = 32'h0;
  endfunction : new

  //--------------------------------------------------------------------------
  // build_phase
  //--------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create analysis exports
    cpu_instr_analysis_export = new("cpu_instr_analysis_export", this);
    imem_analysis_export = new("imem_analysis_export", this);
    dmem_analysis_export = new("dmem_analysis_export", this);

    // Create analysis port
    analysis_export = new("analysis_export", this);

    // Create memory model
    m_dmem = rv32e_dmem_model::type_id::create("m_dmem", this);

    // Create FIFOs
    m_cpu_instr_fifo = new("m_cpu_instr_fifo", this);
    m_imem_fifo = new("m_imem_fifo", this);
    m_dmem_fifo = new("m_dmem_fifo", this);
  endfunction : build_phase

  //--------------------------------------------------------------------------
  // connect_phase
  //--------------------------------------------------------------------------
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    // Connect analysis exports to FIFOs
    cpu_instr_analysis_export.connect(m_cpu_instr_fifo.analysis_export);
    imem_analysis_export.connect(m_imem_fifo.analysis_export);
    dmem_analysis_export.connect(m_dmem_fifo.analysis_export);
  endfunction : connect_phase

  //--------------------------------------------------------------------------
  // run_phase
  //--------------------------------------------------------------------------
  task run_phase(uvm_phase phase);
    super.run_phase(phase);

    phase.raise_objection(this, $sformatf("%s running", get_full_name()));

    fork
      process_cpu_instructions();
      process_imem_operations();
      process_dmem_operations();
    join

    phase.drop_objection(this, $sformatf("%s completed", get_full_name()));
  endtask : run_phase

  //--------------------------------------------------------------------------
  // process_cpu_instructions() - Process CPU instructions
  //--------------------------------------------------------------------------
  task process_cpu_instructions();
    rv32e_seq_item item;
    rv32e_check_result result;
    bit [31:0] result_val;
    bit        result_valid;

    `uvm_info(get_type_name(), "Starting instruction prediction", UVM_MEDIUM)

    forever begin
      // Get next instruction
      m_cpu_instr_fifo.get(item);

      // Predict result
      predict_result(item, result_val, result_valid);

      // Update statistics
      m_total_instructions++;
      update_statistics(item);

      // Update CPU state
      update_cpu_state(item, result_val, result_valid);

      // Create check result
      result = rv32e_check_result::type_id::create("result");
      result.instr_type = item.convert2string();
      result.pc = m_pc;
      result.passed = 1;
      result.reason = "";

      // Send to scoreboard
      analysis_export.write(result);

      // Update PC
      update_pc(item);
    end
  endtask : process_cpu_instructions

  //--------------------------------------------------------------------------
  // predict_result() - Predict the result of an instruction
  //--------------------------------------------------------------------------
  function void predict_result(rv32e_seq_item item, ref bit [31:0] result, ref bit valid);
    bit [31:0] rs1_val;
    bit [31:0] rs2_val;
    bit [31:0] imm;

    valid = 0;
    result = 32'h0;

    // Get register values
    if (item.rs1 != 0) rs1_val = m_registers[item.rs1];
    if (item.rs2 != 0) rs2_val = m_registers[item.rs2];

    // Select immediate
    if (item.csr_imm) begin
      imm = item.imm_i;
    end else if (item.is_load || item.is_alu_i) begin
      imm = item.imm_i;
    end else if (item.is_store) begin
      imm = item.imm_s;
    end else if (item.is_branch) begin
      imm = item.imm_b;
    end else if (item.is_lui || item.is_auipc) begin
      imm = item.imm_u;
    end else if (item.is_jal || item.is_jalr) begin
      imm = item.imm_j;
    end else begin
      imm = 32'h0;
    end

    // Execute instruction
    case (1)
      item.is_alu_r:
        case (item.alu_op)
          4'd0:  result = rs1_val + rs2_val;  // ADD
          4'd1:  result = rs1_val - rs2_val;  // SUB
          4'd2:  result = rs1_val << rs2_val[4:0];  // SLL
          4'd3:  result = ($signed(rs1_val) < $signed(rs2_val)) ? 32'h1 : 32'h0;  // SLT
          4'd4:  result = (rs1_val < rs2_val) ? 32'h1 : 32'h0;  // SLTU
          4'd5:  result = rs1_val ^ rs2_val;  // XOR
          4'd6:  result = rs1_val >> rs2_val[4:0];  // SRL
          4'd7:  result = $signed(rs1_val) >>> rs2_val[4:0];  // SRA
          4'd8:  result = rs1_val | rs2_val;  // OR
          4'd9:  result = rs1_val & rs2_val;  // AND
        endcase

      item.is_alu_i:
        case (item.alu_op)
          4'd0:  result = rs1_val + imm;  // ADDI
          4'd2:  result = rs1_val << imm[4:0];  // SLLI
          4'd6:  result = rs1_val >> imm[4:0];  // SRLI
          4'd7:  result = $signed(rs1_val) >>> imm[4:0];  // SRAI
          4'd8:  result = rs1_val | imm;  // ORI
          4'd9:  result = rs1_val & imm;  // ANDI
          4'd5:  result = rs1_val ^ imm;  // XORI
          4'd3:  result = ($signed(rs1_val) < imm) ? 32'h1 : 32'h0;  // SLTI
          4'd4:  result = (rs1_val < imm) ? 32'h1 : 32'h0;  // SLTUI
        endcase

      item.is_load:
        // Memory read prediction handled by DMEM model
        result = m_dmem.read(item.mem_addr);
        valid = 1;

      item.is_store:
        // Store doesn't produce result
        valid = 0;

      item.is_lui:
        result = imm;
        valid = 1;

      item.is_auipc:
        result = m_pc + imm;
        valid = 1;

      item.is_jal:
        result = m_pc + 4;
        valid = 1;

      item.is_jalr:
        result = m_pc + 4;
        valid = 1;

      item.is_branch:
        // Branch prediction - takes 2 cycles
        valid = 0;

      item.is_csr:
        // CSR operation prediction
        case (item.csr_cmd)
          3'd1:  // CSRRW
            result = get_csr(item.csr_addr);
          3'd2:  // CSRRS
            result = get_csr(item.csr_addr);
          3'd3:  // CSRRC
            result = get_csr(item.csr_addr);
        endcase
        valid = 1;

      default:
        valid = 0;
    endcase
  endfunction : predict_result

  //--------------------------------------------------------------------------
  // update_cpu_state() - Update CPU state based on instruction
  //--------------------------------------------------------------------------
  function void update_cpu_state(rv32e_seq_item item, bit [31:0] result, bit valid);
    // Writeback
    if (item.reg_write && item.rd != 0 && valid) begin
      m_registers[item.rd] = result;
    end

    // Memory write
    if (item.mem_write) begin
      m_dmem.write(item.mem_addr, item.mem_wdata, item.mem_be);
    end
  endfunction : update_cpu_state

  //--------------------------------------------------------------------------
  // update_pc() - Update PC based on instruction type
  //--------------------------------------------------------------------------
  function void update_pc(rv32e_seq_item item);
    if (item.is_branch || item.is_jal || item.is_jalr) begin
      // PC updated in decoder
    end else begin
      m_pc = m_pc + 32'd4;
    end
  endfunction : update_pc

  //--------------------------------------------------------------------------
  // update_statistics() - Update instruction statistics
  //--------------------------------------------------------------------------
  function void update_statistics(rv32e_seq_item item);
    case (1)
      item.is_alu_r: m_alu_instructions++;
      item.is_alu_i: m_alu_instructions++;
      item.is_load:  m_load_instructions++;
      item.is_store: m_store_instructions++;
      item.is_branch: m_branch_instructions++;
      item.is_jal, item.is_jalr: m_jump_instructions++;
      item.is_csr:   m_csr_instructions++;
    endcase
  endfunction : update_statistics

  //--------------------------------------------------------------------------
  // get_csr() - Get CSR value
  //--------------------------------------------------------------------------
  function bit [31:0] get_csr(bit [11:0] addr);
    case (addr)
      12'h300: return {31'h0, m_mstatus_mie};  // MSTATUS
      12'h304: return m_mie;  // MIE
      12'h344: return m_mip;  // MIP
      12'h305: return m_mtvec;  // MTVEC
      12'h341: return m_mepc;  // MEPC
      12'h342: return m_mcause;  // MCAUSE
      default: return 32'h0;
    endcase
  endfunction : get_csr

  //--------------------------------------------------------------------------
  // process_imem_operations() - Process IMEM operations
  //--------------------------------------------------------------------------
  task process_imem_operations();
    rv32e_mem_op op;

    forever begin
      m_imem_fifo.get(op);
      // IMEM is read-only
    end
  endtask : process_imem_operations

  //--------------------------------------------------------------------------
  // process_dmem_operations() - Process DMEM operations
  //--------------------------------------------------------------------------
  task process_dmem_operations();
    rv32e_mem_op op;

    forever begin
      m_dmem_fifo.get(op);

      if (op.is_write) begin
        m_dmem.write(op.addr, op.data, op.be);
      end
    end
  endtask : process_dmem_operations

  //--------------------------------------------------------------------------
  // extract_phase
  //--------------------------------------------------------------------------
  function void extract_phase(uvm_phase phase);
    super.extract_phase(phase);

    `uvm_info(get_type_name(), 
      $sformatf("Predictor Statistics:\n" &
                "  Total Instructions:   %0d\n" &
                "  ALU:                  %0d\n" &
                "  Load:                 %0d\n" &
                "  Store:                %0d\n" &
                "  Branch:               %0d\n" &
                "  Jump:                 %0d\n" &
                "  CSR:                  %0d",
                m_total_instructions, m_alu_instructions, m_load_instructions,
                m_store_instructions, m_branch_instructions, m_jump_instructions,
                m_csr_instructions), UVM_LOW)
  endfunction : extract_phase

endclass : rv32e_predictor

`endif // RV32E_PREDICTOR_SV
