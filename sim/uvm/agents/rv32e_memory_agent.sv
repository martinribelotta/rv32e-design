`ifndef RV32E_MEMORY_AGENT_SV
`define RV32E_MEMORY_AGENT_SV

/**
 * Memory agent for RV32E.
 * Monitors and drives memory operations (IMEM and DMEM).
 */
class rv32e_memory_agent extends uvm_agent;

  // Components
  rv32e_memory_driver     m_driver;
  rv32e_memory_monitor    m_monitor;
  uvm_sequencer#(rv32e_seq_item) m_sequencer;

  // Configuration
  bit m_active = 1;
  int m_imem_depth = 1024;
  int m_dmem_depth = 1024;

  // Memory models
  rv32e_imem_model m_imem;
  rv32e_dmem_model m_dmem;

  // Analysis ports
  uvm_analysis_port#(rv32e_mem_op) imem_op_ap;
  uvm_analysis_port#(rv32e_mem_op) dmem_op_ap;

  // TLM FIFOs
  uvm_tlm_analysis_fifo#(rv32e_mem_op) m_imem_fifo;
  uvm_tlm_analysis_fifo#(rv32e_mem_op) m_dmem_fifo;

  `uvm_component_utils_begin(rv32e_memory_agent)
    `uvm_field_int(m_active, UVM_DEFAULT)
    `uvm_field_int(m_imem_depth, UVM_DEFAULT)
    `uvm_field_int(m_dmem_depth, UVM_DEFAULT)
  `uvm_component_utils_end

  //--------------------------------------------------------------------------
  // Constructor
  //--------------------------------------------------------------------------
  function new(string name = "rv32e_memory_agent", uvm_component parent = null);
    super.new(name, parent);
    m_imem_fifo = null;
    m_dmem_fifo = null;
  endfunction : new

  //--------------------------------------------------------------------------
  // build_phase
  //--------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Get configuration
    void'(uvm_config_db#(bit)::get(this, "", "active", m_active));
    void'(uvm_config_db#(int)::get(this, "", "imem_depth", m_imem_depth));
    void'(uvm_config_db#(int)::get(this, "", "dmem_depth", m_dmem_depth));

    // Create components
    if (m_active) begin
      m_driver = rv32e_memory_driver::type_id::create("m_driver", this);
      m_sequencer = uvm_sequencer#(rv32e_seq_item)::type_id::create("m_sequencer", this);
    end

    m_monitor = rv32e_memory_monitor::type_id::create("m_monitor", this);

    // Create memory models
    m_imem = rv32e_imem_model::type_id::create("m_imem", this);
    m_dmem = rv32e_dmem_model::type_id::create("m_dmem", this);
    m_imem.set_depth(m_imem_depth);
    m_dmem.set_depth(m_dmem_depth);

    // Create analysis ports
    imem_op_ap = new("imem_op_ap", this);
    dmem_op_ap = new("dmem_op_ap", this);

    // Create FIFOs for main agent
    if (get_full_name() == "m_env.memory_agent") begin
      m_imem_fifo = new("m_imem_fifo", this);
      m_dmem_fifo = new("m_dmem_fifo", this);
    end
  endfunction : build_phase

  //--------------------------------------------------------------------------
  // connect_phase
  //--------------------------------------------------------------------------
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    if (m_active) begin
      m_driver.seq_item_port.connect(m_sequencer.seq_item_export);
    end

    // Connect monitor outputs
    m_monitor.imem_op_ap.connect(imem_op_ap);
    m_monitor.dmem_op_ap.connect(dmem_op_ap);

    // Connect to FIFOs
    if (m_imem_fifo != null) begin
      imem_op_ap.connect(m_imem_fifo.analysis_export);
    end
    if (m_dmem_fifo != null) begin
      dmem_op_ap.connect(m_dmem_fifo.analysis_export);
    end
  endfunction : connect_phase

  //--------------------------------------------------------------------------
  // load_firmware() - Load firmware into IMEM
  //--------------------------------------------------------------------------
  function void load_firmware(string hex_file);
    m_imem.load_hex(hex_file);
  endfunction : load_firmware

endclass : rv32e_memory_agent

// Memory operation class
class rv32e_mem_op extends uvm_sequence_item;

  rand bit        is_read;
  rand bit        is_write;
  rand bit        is_imem;
  rand bit        is_dmem;
  rand bit [31:0] addr;
  rand bit [31:0] data;
  rand bit [3:0]  be;
  rand int        latency;

  constraint c_addr_aligned {
    addr[1:0] == 2'b00;  // Word-aligned
  }

  constraint c_be_nonzero {
    if (is_write) be != 4'b0000;
  }

  function new(string name = "rv32e_mem_op");
    super.new(name);
  endfunction : new

  function string convert2string();
    string s;
    s = $sformatf("[%s %s] addr=0x%08x data=0x%08x be=0x%x", 
                  is_read ? "READ" : "WRITE",
                  is_imem ? "IMEM" : "DMEM",
                  addr, data, be);
    return s;
  endfunction : convert2string

  function void copy(uvm_sequence_item item);
    rv32e_mem_op rhs;
    if (!$cast(rhs, item)) return;
    is_read  = rhs.is_read;
    is_write = rhs.is_write;
    is_imem  = rhs.is_imem;
    is_dmem  = rhs.is_dmem;
    addr     = rhs.addr;
    data     = rhs.data;
    be       = rhs.be;
    latency  = rhs.latency;
  endfunction : copy

  function bit compare(uvm_sequence_item item);
    rv32e_mem_op rhs;
    if (!$cast(rhs, item)) return 0;
    return (is_read == rhs.is_read && is_write == rhs.is_write &&
            is_imem == rhs.is_imem && is_dmem == rhs.is_dmem &&
            addr == rhs.addr && data == rhs.data && be == rhs.be);
  endfunction : compare

endclass : rv32e_mem_op

`endif // RV32E_MEMORY_AGENT_SV
