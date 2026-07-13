`ifndef RV32E_CPU_MONITOR_SV
`define RV32E_CPU_MONITOR_SV

/**
 * CPU monitor for RV32E.
 * Monitors the CPU pipeline and captures instruction execution.
 */
class rv32e_cpu_monitor extends uvm_monitor;

  // DUT interface connections
  virtual interface rv32e_if vif;

  // Configuration
  int m_max_cycles = 100000;

  // Analysis ports
  uvm_analysis_port#(rv32e_seq_item) instruction_ap;
  uvm_analysis_port#(bit[31:0])      pc_ap;
  uvm_analysis_port#(bit[31:0])      result_ap;

  // State
  int m_instr_count = 0;

  `uvm_component_utils(rv32e_cpu_monitor)

  //--------------------------------------------------------------------------
  // Constructor
  //--------------------------------------------------------------------------
  function new(string name = "rv32e_cpu_monitor", uvm_component parent = null);
    super.new(name, parent);
    m_instr_count = 0;
  endfunction : new

  //--------------------------------------------------------------------------
  // build_phase
  //--------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Get DUT interface
    if (!uvm_config_db#(virtual interface rv32e_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NOVIF", "Virtual interface not found for rv32e_cpu_monitor")
    end

    // Get configuration
    void'(uvm_config_db#(int)::get(this, "", "max_cycles", m_max_cycles));

    // Create analysis ports
    instruction_ap = new("instruction_ap", this);
    pc_ap = new("pc_ap", this);
    result_ap = new("result_ap", this);
  endfunction : build_phase

  //--------------------------------------------------------------------------
  // run_phase
  //--------------------------------------------------------------------------
  task run_phase(uvm_phase phase);
    super.run_phase(phase);

    // Start monitoring
    fork
      monitor_pipeline();
      wait_for_completion();
    join
  endtask : run_phase

  //--------------------------------------------------------------------------
  // monitor_pipeline() - Monitor CPU pipeline stages
  //--------------------------------------------------------------------------
  task monitor_pipeline();
    rv32e_seq_item item;
    bit [31:0] last_pc = 0;

    // Wait for reset release
    @(negedge vif.rst_n);
    @(posedge vif.rst_n);

    forever begin
      @(posedge vif.clk);

      // Monitor IF stage
      if (vif.pc != last_pc) begin
        last_pc = vif.pc;
        pc_ap.write(last_pc);
      end

      // Monitor ID/EX stage
      // (Decode signals)
      if (vif.valid && vif.instr_ready) begin
        item = rv32e_seq_item::type_id::create("monitored_item");
        item.opcode    = vif.opcode;
        item.rs1       = vif.rs1;
        item.rs2       = vif.rs2;
        item.rd        = vif.rd;
        item.funct3    = vif.funct3;
        item.funct7    = vif.funct7;
        item.imm_i     = vif.imm_i;
        item.imm_s     = vif.imm_s;
        item.imm_b     = vif.imm_b;
        item.imm_u     = vif.imm_u;
        item.imm_j     = vif.imm_j;
        item.alu_op    = vif.alu_op;
        item.reg_write = vif.reg_write;
        item.mem_read  = vif.mem_read;
        item.mem_write = vif.mem_write;
        item.commit    = vif.commit;

        instruction_ap.write(item);
        m_instr_count++;
      end

      // Monitor MEM/WB stage
      if (vif.result_valid) begin
        result_ap.write(vif.result);
      end
    end
  endtask : monitor_pipeline

  //--------------------------------------------------------------------------
  // wait_for_completion() - Wait for test completion
  //--------------------------------------------------------------------------
  task wait_for_completion();
    int cycle_count = 0;

    while (cycle_count < m_max_cycles) begin
      @(posedge vif.clk);
      cycle_count++;
    end

    `uvm_info(get_type_name(), $sformatf("Monitor completed: %0d instructions", m_instr_count), UVM_LOW)
  endtask : wait_for_completion

endclass : rv32e_cpu_monitor

`endif // RV32E_CPU_MONITOR_SV
