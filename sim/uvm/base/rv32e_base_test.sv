`ifndef RV32E_BASE_TEST_SV
`define RV32E_BASE_TEST_SV

/**
 * Base test class for RV32E UVM verification environment.
 * Provides common setup, configuration, and teardown functionality.
 * All tests inherit from this base class.
 */
class rv32e_base_test extends uvm_test;

  // Environment handle
  rv32e_env m_env;

  // Test configuration
  string m_test_name = "rv32e_base_test";
  int    m_max_cycles = 100000;
  bit    m_enable_coverage = 1;
  bit    m_enable_assertions = 1;

  // Analysis ports for logging
  uvm_tlm_analysis_fifo #(uvm_component) m_comp_fifo;

  `uvm_component_utils(rv32e_base_test)

  //--------------------------------------------------------------------------
  // Constructor
  //--------------------------------------------------------------------------
  function new(string name = "rv32e_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  //--------------------------------------------------------------------------
  // build_phase
  //--------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    `uvm_info(get_type_name(), "Building RV32E UVM environment...", UVM_MEDIUM)

    // Create environment
    m_env = rv32e_env::type_id::create("m_env", this);

    // Set configuration
    uvm_config_db#(int)::set(this, "m_env", "max_cycles", m_max_cycles);
    uvm_config_db#(bit)::set(this, "m_env", "enable_coverage", m_enable_coverage);
    uvm_config_db#(bit)::set(this, "m_env", "enable_assertions", m_enable_assertions);

    // Create FIFO for component monitoring
    m_comp_fifo = new("m_comp_fifo", this);

    super.build_phase(phase);
  endfunction : build_phase

  //--------------------------------------------------------------------------
  // connect_phase
  //--------------------------------------------------------------------------
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
  endfunction : connect_phase

  //--------------------------------------------------------------------------
  // run_phase
  //--------------------------------------------------------------------------
  task run_phase(uvm_phase phase);
    string vlogan_opts;
    string vsim_opts;
    string vcs_opts;

    `uvm_info(get_type_name(), $sformatf("Starting test: %s", m_test_name), UVM_LOW)

    // Start the simulation
    phase.raise_objection(this, $sformatf("Running %s", m_test_name));

    // Run for specified cycles or until objection is dropped
    #1us;  // Allow environment to stabilize

    // Default run time - tests should drop objection when done
    #100us;

    `uvm_info(get_type_name(), "Test completed successfully", UVM_LOW)

    phase.drop_objection(this, $sformatf("Completed %s", m_test_name));
  endfunction : run_phase

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
    uvm_report_server svr;
    int error_count;
    int warning_count;

    super.report_phase(phase);

    svr = uvm_report_server::get_server();
    error_count = svr.get_number_of_errors();
    warning_count = svr.get_number_of_warnings();

    `uvm_info(get_type_name(), 
      $sformatf("=== UVM Report Summary ===\n" &
                "Errors: %0d\n" &
                "Warnings: %0d\n" &
                "Test Name: %s", 
                error_count, warning_count, m_test_name), UVM_LOW)

    if (error_count > 0) begin
      `uvm_error(get_type_name(), $sformatf("Test FAILED with %0d errors", error_count))
    end
  endfunction : report_phase

  //--------------------------------------------------------------------------
  // final_phase
  //--------------------------------------------------------------------------
  function void final_phase(uvm_phase phase);
    `uvm_info(get_type_name(), "Final phase - cleaning up", UVM_FULL)
    super.final_phase(phase);
  endfunction : final_phase

endclass : rv32e_base_test

`endif // RV32E_BASE_TEST_SV
