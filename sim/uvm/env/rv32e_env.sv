`ifndef RV32E_ENV_SV
`define RV32E_ENV_SV

/**
 * RV32E UVM Environment.
 * Top-level component that instantiates and connects all sub-components.
 */
class rv32e_env extends uvm_env;

  // Components
  rv32e_cpu_agent       cpu_agent;
  rv32e_memory_agent    memory_agent;
  rv32e_peripheral_agent peripheral_agent;

  rv32e_scoreboard      scoreboard;
  rv32e_predictor       predictor;
  rv32e_coverage        coverage;

  // Virtual interface
  virtual interface rv32e_if vif;

  // Configuration
  int m_max_cycles = 100000;
  bit m_enable_coverage = 1;
  bit m_enable_assertions = 1;

  // Analysis FIFOs
  uvm_tlm_analysis_fifo#(rv32e_seq_item) cpu_instr_fifo;
  uvm_tlm_analysis_fifo#(rv32e_mem_op) imem_fifo;
  uvm_tlm_analysis_fifo#(rv32e_mem_op) dmem_fifo;

  // TLM FIFOs for predictor
  uvm_tlm_analysis_fifo#(rv32e_seq_item) cpu_to_predictor_fifo;
  uvm_tlm_analysis_fifo#(rv32e_mem_op) imem_to_predictor_fifo;
  uvm_tlm_analysis_fifo#(rv32e_mem_op) dmem_to_predictor_fifo;

  // Factory overrides
  static bit m_factory_overrides_applied = 0;

  `uvm_component_utils_begin(rv32e_env)
    `uvm_field_int(m_max_cycles, UVM_DEFAULT)
    `uvm_field_int(m_enable_coverage, UVM_DEFAULT)
    `uvm_field_int(m_enable_assertions, UVM_DEFAULT)
  `uvm_component_utils_end

  //--------------------------------------------------------------------------
  // Constructor
  //--------------------------------------------------------------------------
  function new(string name = "rv32e_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  //--------------------------------------------------------------------------
  // build_phase
  //--------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Get configuration
    void'(uvm_config_db#(int)::get(this, "", "max_cycles", m_max_cycles));
    void'(uvm_config_db#(bit)::get(this, "", "enable_coverage", m_enable_coverage));
    void'(uvm_config_db#(bit)::get(this, "", "enable_assertions", m_enable_assertions));

    // Get virtual interface
    if (!uvm_config_db#(virtual interface rv32e_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NOVIF", "Virtual interface not found for rv32e_env")
    end

    // Create components
    cpu_agent = rv32e_cpu_agent::type_id::create("cpu_agent", this);
    memory_agent = rv32e_memory_agent::type_id::create("memory_agent", this);
    peripheral_agent = rv32e_peripheral_agent::type_id::create("peripheral_agent", this);

    scoreboard = rv32e_scoreboard::type_id::create("scoreboard", this);
    predictor = rv32e_predictor::type_id::create("predictor", this);
    
    if (m_enable_coverage) begin
      coverage = rv32e_coverage::type_id::create("coverage", this);
    end

    // Create analysis FIFOs
    cpu_instr_fifo = new("cpu_instr_fifo", this);
    imem_fifo = new("imem_fifo", this);
    dmem_fifo = new("dmem_fifo", this);

    cpu_to_predictor_fifo = new("cpu_to_predictor_fifo", this);
    imem_to_predictor_fifo = new("imem_to_predictor_fifo", this);
    dmem_to_predictor_fifo = new("dmem_to_predictor_fifo", this);
  endfunction : build_phase

  //--------------------------------------------------------------------------
  // connect_phase
  //--------------------------------------------------------------------------
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    // Connect CPU agent
    cpu_agent.instruction_ap.connect(cpu_instr_fifo.analysis_export);
    cpu_agent.instruction_ap.connect(scoreboard.instr_analysis_export);
    cpu_agent.instruction_ap.connect(predictor.cpu_instr_analysis_export);

    // Connect memory agent
    memory_agent.imem_op_ap.connect(imem_fifo.analysis_export);
    memory_agent.dmem_op_ap.connect(dmem_fifo.analysis_export);
    memory_agent.imem_op_ap.connect(scoreboard.imem_analysis_export);
    memory_agent.dmem_op_ap.connect(scoreboard.dmem_analysis_export);
    memory_agent.imem_op_ap.connect(predictor.imem_analysis_export);
    memory_agent.dmem_op_ap.connect(predictor.dmem_analysis_export);

    // Connect to predictor
    cpu_instr_fifo.connect(cpu_to_predictor_fifo.analysis_export);
    imem_fifo.connect(imem_to_predictor_fifo.analysis_export);
    dmem_fifo.connect(dmem_to_predictor_fifo.analysis_export);

    // Connect scoreboard
    scoreboard.predictor_analysis_port.connect(predictor.analysis_export);

    // Connect coverage
    if (m_enable_coverage) begin
      cpu_agent.instruction_ap.connect(coverage.cpu_instr_analysis_export);
      memory_agent.imem_op_ap.connect(coverage.imem_analysis_export);
      memory_agent.dmem_op_ap.connect(coverage.dmem_analysis_export);
    end
  endfunction : connect_phase

  //--------------------------------------------------------------------------
  // start_of_simulation_phase
  //--------------------------------------------------------------------------
  function void start_of_simulation_phase(uvm_phase phase);
    `uvm_info(get_type_name(), "Starting RV32E environment simulation", UVM_LOW)

    if (m_enable_assertions) begin
      `uvm_info(get_type_name(), "Enabling SVA assertions", UVM_FULL)
      // Assertions are instantiated in top-level module
    end

    // Load firmware into IMEM
    string hex_file = uvm_config_db#(string)::get(null, "*", "firmware_hex");
    if (hex_file != "") begin
      memory_agent.load_firmware(hex_file);
    end
  endfunction : start_of_simulation_phase

  //--------------------------------------------------------------------------
  // extract_phase
  //--------------------------------------------------------------------------
  function void extract_phase(uvm_phase phase);
    super.extract_phase(phase);
  endfunction : extract_phase

  //--------------------------------------------------------------------------
  // report_phase
  //--------------------------------------------------------------------------
  function void report_phase(uvm_phase phase);
    string report_str;

    super.report_phase(phase);

    // Generate coverage report
    if (m_enable_coverage && coverage != null) begin
      coverage.report_coverage();
    end
  endfunction : report_phase

  //--------------------------------------------------------------------------
  // apply_factory_overrides() - Apply factory overrides for test customization
  //--------------------------------------------------------------------------
  static function void apply_factory_overrides();
    if (m_factory_overrides_applied) return;

    `uvm_info("FACTORY", "Applying factory overrides", UVM_FULL)

    // Override components with test-specific versions
    // This allows tests to customize behavior without modifying base classes

    m_factory_overrides_applied = 1;
  endfunction : apply_factory_overrides

endclass : rv32e_env

`endif // RV32E_ENV_SV
