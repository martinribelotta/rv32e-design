`ifndef RV32E_VIRTUAL_SEQUENCER_SV
`define RV32E_VIRTUAL_SEQUENCER_SV

/**
 * RV32E Virtual Sequencer.
 * Coordinates multiple sequencers for complex test scenarios.
 */
class rv32e_virtual_sequencer extends uvm_sequencer;

  // Sequencer handles
  uvm_sequencer#(rv32e_seq_item) cpu_sequencer;
  uvm_sequencer#(rv32e_mem_op)   imem_sequencer;
  uvm_sequencer#(rv32e_mem_op)   dmem_sequencer;

  // Virtual interface
  virtual interface rv32e_if vif;

  `uvm_component_utils(rv32e_virtual_sequencer)

  //--------------------------------------------------------------------------
  // Constructor
  //--------------------------------------------------------------------------
  function new(string name = "rv32e_virtual_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  //--------------------------------------------------------------------------
  // build_phase
  //--------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Get virtual interface
    if (!uvm_config_db#(virtual interface rv32e_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NOVIF", "Virtual interface not found for rv32e_virtual_sequencer")
    end
  endfunction : build_phase

  //--------------------------------------------------------------------------
  // connect_phase
  //--------------------------------------------------------------------------
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    // Get sequencer handles from environment
    if (!uvm_config_db#(uvm_sequencer#(rv32e_seq_item))::get(this, "", "cpu_sequencer", cpu_sequencer)) begin
      `uvm_warning("NOSEQ", "CPU sequencer not found")
    end

    if (!uvm_config_db#(uvm_sequencer#(rv32e_mem_op))::get(this, "", "imem_sequencer", imem_sequencer)) begin
      `uvm_warning("NOSEQ", "IMEM sequencer not found")
    end

    if (!uvm_config_db#(uvm_sequencer#(rv32e_mem_op))::get(this, "", "dmem_sequencer", dmem_sequencer)) begin
      `uvm_warning("NOSEQ", "DMEM sequencer not found")
    end
  endfunction : connect_phase

endclass : rv32e_virtual_sequencer

`endif // RV32E_VIRTUAL_SEQUENCER_SV
