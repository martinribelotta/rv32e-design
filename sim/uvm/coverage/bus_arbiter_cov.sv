`ifndef BUS_ARBITER_COV_SV
`define BUS_ARBITER_COV_SV

/**
 * Bus Arbitrator Coverage: Functional coverage for bus arbitration logic
 */
class bus_arbiter_coverage extends uvm_component;
  `uvm_component_utils(bus_arbiter_coverage)

  // Monitor port for observing arbitration transactions
  uvm_analysis_export#(rv32e_mem_op) arb_export;
  uvm_tlm_analysis_fifo#(rv32e_mem_op) arb_fifo;

  // Coverage group: bus arbitration decisions
  covergroup cg_bus_arbitration;
    option.per_instance = 1;

    // IMEM request coverage
    cp_imem_req: coverpoint last_op.imem_req {
      bins req_asserted = {1'b1};
      bins req_deasserted = {1'b0};
    }

    // DMEM request coverage
    cp_dmem_req: coverpoint last_op.dmem_req {
      bins req_asserted = {1'b1};
      bins req_deasserted = {1'b0};
    }

    // Arbitration decision
    cp_arb_decision: coverpoint last_op.arb_decision {
      bins imem_grants = {ARB_IMEM};
      bins dmem_grants = {ARB_DMEM};
      bins no_grant = {ARB_NONE};
    }

    // Wait state signal
    cp_wait_state: coverpoint last_op.bus_wait {
      bins wait_asserted = {1'b1};
      bins wait_released = {1'b0};
    }

    // Cross coverage: simultaneous request patterns
    cx_simultaneous_requests: cross cp_imem_req, cp_dmem_req {
      bins no_requests = binsof(cp_imem_req) intersect {1'b0} && binsof(cp_dmem_req) intersect {1'b0};
      bins imem_only = binsof(cp_imem_req) intersect {1'b1} && binsof(cp_dmem_req) intersect {1'b0};
      bins dmem_only = binsof(cp_imem_req) intersect {1'b0} && binsof(cp_dmem_req) intersect {1'b1};
      bins both = binsof(cp_imem_req) intersect {1'b1} && binsof(cp_dmem_req) intersect {1'b1};
    }

    // Cross coverage: decision vs. request pattern
    cx_decision_vs_request: cross cp_arb_decision, cx_simultaneous_requests {
      ignore_bins impossible_dmem = binsof(cp_arb_decision) intersect {ARB_DMEM} && binsof(cx_simultaneous_requests) intersect {no_requests, imem_only};
      ignore_bins impossible_imem = binsof(cp_arb_decision) intersect {ARB_IMEM} && binsof(cx_simultaneous_requests) intersect {no_requests, dmem_only};
    }

    // Cross coverage: priority verification (DMEM > IMEM)
    cx_priority_verification: cross cp_dmem_req, cp_arb_decision {
      bins dmem_priority = binsof(cp_dmem_req) intersect {1'b1} && binsof(cp_arb_decision) intersect {ARB_DMEM};
      illegal_bins dmem_denied = binsof(cp_dmem_req) intersect {1'b1} && binsof(cp_arb_decision) intersect {ARB_IMEM, ARB_NONE};
    }

  endgroup : cg_bus_arbitration

  // Coverage group: wait state behavior
  covergroup cg_wait_states;
    option.per_instance = 1;

    // Wait counter depth
    cp_wait_cnt: coverpoint last_wait_cnt {
      bins zero = {0};
      bins one = {1};
      bins two = {2};
      bins multi = {[3:$]};
    }

    // Wait assertion/de-assertion transitions
    cp_wait_transition: coverpoint wait_transition {
      bins deassert_to_assert = {WAIT_DEASSERT};
      bins assert_to_deassert = {WAIT_ASSERT};
      bins assert_maintained = {WAIT_MAINTAINED};
      bins deassert_maintained = {WAIT_DEASSERT_MAINTAINED};
    }

    // Cross: wait counter vs. conflict rate
    cx_conflict_rate: cross cp_wait_cnt, cp_imem_req, cp_dmem_req {
      // High conflict rate should see deeper wait counters
      // Low conflict rate should see mostly counter = 0
    }

  endgroup : cg_wait_states

  // Internal tracking
  rv32e_mem_op last_op;
  rv32e_mem_op prev_op;
  bit [3:0] last_wait_cnt;
  bit prev_bus_wait;
  enum { WAIT_DEASSERT, WAIT_ASSERT, WAIT_MAINTAINED, WAIT_DEASSERT_MAINTAINED } wait_transition;

  function new(string name = "bus_arbiter_coverage", uvm_component parent = null);
    super.new(name, parent);
    cg_bus_arbitration = new();
    cg_wait_states = new();
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    arb_export = new("arb_export", this);
    arb_fifo = new("arb_fifo", this);
  endfunction : build_phase

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    arb_export.connect(arb_fifo.analysis_export);
  endfunction : connect_phase

  task run_phase(uvm_phase phase);
    forever begin
      arb_fifo.get(last_op);
      sample_coverage();
    end
  endtask : run_phase

  function void sample_coverage();
    // Determine wait transition
    if (prev_bus_wait && !last_op.bus_wait) begin
      wait_transition = WAIT_DEASSERT;
    end else if (!prev_bus_wait && last_op.bus_wait) begin
      wait_transition = WAIT_ASSERT;
    end else if (prev_bus_wait && last_op.bus_wait) begin
      wait_transition = WAIT_MAINTAINED;
    end else begin
      wait_transition = WAIT_DEASSERT_MAINTAINED;
    end

    // Store for next iteration
    prev_op = last_op;
    prev_bus_wait = last_op.bus_wait;
    last_wait_cnt = last_op.wait_cnt;

    // Sample covergroups
    cg_bus_arbitration.sample();
    cg_wait_states.sample();
  endfunction : sample_coverage

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("bus_arbiter_coverage", "Bus Arbitrator Coverage Report:", UVM_MEDIUM)
    `uvm_info("bus_arbiter_coverage", $sformatf("Coverage: %0.2f%%", 
                                                 cg_bus_arbitration.get_coverage()), UVM_MEDIUM)
  endfunction : report_phase

endclass : bus_arbiter_coverage

`endif // BUS_ARBITER_COV_SV
