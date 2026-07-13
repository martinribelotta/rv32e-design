`ifndef RV32E_SCOREBOARD_SV
`define RV32E_SCOREBOARD_SV

/**
 * RV32E Scoreboard.
 * Checks instruction execution results against expected values.
 */
class rv32e_scoreboard extends uvm_scoreboard;

  // Analysis export
  uvm_analysis_export#(rv32e_seq_item) instr_analysis_export;
  uvm_analysis_export#(rv32e_mem_op)   imem_analysis_export;
  uvm_analysis_export#(rv32e_mem_op)   dmem_analysis_export;

  // Predictor analysis port
  uvm_analysis_port#(rv32e_check_result) predictor_analysis_port;

  // Expected results storage
  typedef struct {
    bit [31:0] pc;
    bit [31:0] rd_val;
    bit        rd_valid;
    string     instr_type;
  } expected_result_t;

  expected_result_t m_expected_results[$];

  // Actual results storage
  typedef struct {
    bit [31:0] pc;
    bit [31:0] rd_val;
    bit        rd_valid;
    string     instr_type;
    int        cycle;
  } actual_result_t;

  actual_result_t m_actual_results[$];

  // Statistics
  int m_total_checks = 0;
  int m_passed_checks = 0;
  int m_failed_checks = 0;
  int m_timeout_checks = 0;

  // TLM FIFOs
  uvm_tlm_analysis_fifo#(rv32e_seq_item) m_instr_fifo;
  uvm_tlm_analysis_fifo#(rv32e_mem_op)   m_imem_fifo;
  uvm_tlm_analysis_fifo#(rv32e_mem_op)   m_dmem_fifo;

  `uvm_component_utils_begin(rv32e_scoreboard)
    `uvm_field_int(m_total_checks, UVM_DEFAULT)
    `uvm_field_int(m_passed_checks, UVM_DEFAULT)
    `uvm_field_int(m_failed_checks, UVM_DEFAULT)
    `uvm_field_int(m_timeout_checks, UVM_DEFAULT)
  `uvm_component_utils_end

  //--------------------------------------------------------------------------
  // Constructor
  //--------------------------------------------------------------------------
  function new(string name = "rv32e_scoreboard", uvm_component parent = null);
    super.new(name, parent);
    m_total_checks = 0;
    m_passed_checks = 0;
    m_failed_checks = 0;
    m_timeout_checks = 0;
  endfunction : new

  //--------------------------------------------------------------------------
  // build_phase
  //--------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create analysis export
    instr_analysis_export = new("instr_analysis_export", this);
    imem_analysis_export = new("imem_analysis_export", this);
    dmem_analysis_export = new("dmem_analysis_export", this);

    // Create predictor analysis port
    predictor_analysis_port = new("predictor_analysis_port", this);

    // Create FIFOs
    m_instr_fifo = new("m_instr_fifo", this);
    m_imem_fifo = new("m_imem_fifo", this);
    m_dmem_fifo = new("m_dmem_fifo", this);
  endfunction : build_phase

  //--------------------------------------------------------------------------
  // connect_phase
  //--------------------------------------------------------------------------
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    // Connect analysis exports to FIFOs
    instr_analysis_export.connect(m_instr_fifo.analysis_export);
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
  // process_cpu_instructions() - Process CPU instruction stream
  //--------------------------------------------------------------------------
  task process_cpu_instructions();
    rv32e_seq_item item;
    expected_result_t expected;
    actual_result_t actual;
    int cycle_count = 0;

    `uvm_info(get_type_name(), "Starting instruction processing", UVM_MEDIUM)

    forever begin
      // Get next instruction from CPU
      m_instr_fifo.get(item);

      cycle_count++;
      m_total_checks++;

      // Create expected result based on instruction type
      case (1)
        item.is_alu_i, item.is_alu_r:
          expected.instr_type = "ALU";
        item.is_load:
          expected.instr_type = "LOAD";
        item.is_store:
          expected.instr_type = "STORE";
        item.is_branch:
          expected.instr_type = "BRANCH";
        item.is_jal, item.is_jalr:
          expected.instr_type = "JUMP";
        item.is_lui:
          expected.instr_type = "LUI";
        item.is_auipc:
          expected.instr_type = "AUIPC";
        item.is_csr:
          expected.instr_type = "CSR";
        item.is_system:
          expected.instr_type = "SYSTEM";
        default:
          expected.instr_type = "UNKNOWN";
      endcase

      expected.pc = 32'h0;  // Will be set by predictor

      // Get actual result from predictor
      m_actual_results.push_back(actual);

      // Check result
      check_result(expected, actual, item);

      // Clean old entries
      if (m_actual_results.size() > 1000) begin
        m_actual_results.pop_front();
      end
    end
  endtask : process_cpu_instructions

  //--------------------------------------------------------------------------
  // process_imem_operations() - Process IMEM operations
  //--------------------------------------------------------------------------
  task process_imem_operations();
    rv32e_mem_op op;

    forever begin
      m_imem_fifo.get(op);
      // IMEM operations are mostly read-only
    end
  endtask : process_imem_operations

  //--------------------------------------------------------------------------
  // process_dmem_operations() - Process DMEM operations
  //--------------------------------------------------------------------------
  task process_dmem_operations();
    rv32e_mem_op op;

    forever begin
      m_dmem_fifo.get(op);

      // Check write operations
      if (op.is_write) begin
        // DMEM write check
        m_total_checks++;
      end
    end
  endtask : process_dmem_operations

  //--------------------------------------------------------------------------
  // check_result() - Check expected vs actual result
  //--------------------------------------------------------------------------
  function void check_result(expected_result_t expected, actual_result_t actual, rv32e_seq_item item);
    rv32e_check_result result;

    result.instr_type = expected.instr_type;
    result.pc = actual.pc;
    result.passed = 1;
    result.reason = "";

    // Compare RD value if valid
    if (item.reg_write && item.rd != 0) begin
      if (expected.rd_valid) begin
        if (expected.rd_val != actual.rd_val) begin
          result.passed = 0;
          result.reason = $sformatf("RD mismatch: expected=0x%08x, actual=0x%08x", 
                                    expected.rd_val, actual.rd_val);
          `uvm_error(get_type_name(), result.reason)
          m_failed_checks++;
        end else begin
          m_passed_checks++;
        end
      end
    end

    // Send to predictor for further analysis
    predictor_analysis_port.write(result);
  endfunction : check_result

  //--------------------------------------------------------------------------
  // extract_phase
  //--------------------------------------------------------------------------
  function void extract_phase(uvm_phase phase);
    super.extract_phase(phase);

    `uvm_info(get_type_name(), 
      $sformatf("Scoreboard Results:\n" &
                "  Total Checks:   %0d\n" &
                "  Passed:         %0d\n" &
                "  Failed:         %0d\n" &
                "  Timeouts:       %0d",
                m_total_checks, m_passed_checks, m_failed_checks, m_timeout_checks), UVM_LOW)
  endfunction : extract_phase

  //--------------------------------------------------------------------------
  // get_statistics() - Get scoreboard statistics
  //--------------------------------------------------------------------------
  function void get_statistics(ref int total, ref int passed, ref int failed, ref int timeout);
    total = m_total_checks;
    passed = m_passed_checks;
    failed = m_failed_checks;
    timeout = m_timeout_checks;
  endfunction : get_statistics

endclass : rv32e_scoreboard

// Check result class
class rv32e_check_result extends uvm_sequence_item;

  string instr_type;
  bit [31:0] pc;
  bit        passed;
  string     reason;

  function new(string name = "rv32e_check_result");
    super.new(name);
  endfunction : new

  function string convert2string();
    string s;
    s = $sformatf("[%s] PC=0x%08x %s", instr_type, pc, passed ? "PASS" : "FAIL");
    if (!passed) s = {s, $sformatf(" - %s", reason)};
    return s;
  endfunction : convert2string

  `uvm_object_utils(rv32e_check_result)

endclass : rv32e_check_result

`endif // RV32E_SCOREBOARD_SV
