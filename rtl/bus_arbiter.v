// Bus Arbitrator: arbitrates access between IMEM (instruction) and DMEM (data)
// when both request access to the unified 2R1W memory.
//
// Arbitration strategy: PRIORITY mode
//   - IMEM (instruction fetch) has LOWER priority
//   - DMEM (data read/write) has HIGHER priority
// This prevents data hazards and stalls from blocking instruction prefetch recovery.
//
// Wait State Generation:
//   - When a request is granted, no wait state (wait_o = 0).
//   - When a request is denied (arbitrated away), wait_o = 1 for that port.
//   - CPU pipeline should stall when wait_o = 1.
//
module bus_arbiter (
    input  wire clk,
    input  wire rst_n,

    // IMEM (instruction) port
    input  wire        imem_req,      // request line (asserted when fetch needed)
    output wire        imem_grant,    // grant: this cycle, IMEM uses the bus
    output wire        imem_wait,     // wait: request denied, stall one cycle

    // DMEM (data) port
    input  wire        dmem_req,      // request line (asserted on read/write)
    output wire        dmem_grant,    // grant: this cycle, DMEM uses the bus
    output wire        dmem_wait,     // wait: request denied, stall one cycle

    // Arbiter output: which port is granted this cycle
    output wire        arb_imem_sel   // 1=IMEM granted, 0=DMEM granted
);

    // Simple priority arbitration: DMEM > IMEM
    // If both request, DMEM gets priority.
    // If only one requests, that one gets it.
    // If neither requests, no one is granted.

    wire dmem_has_priority = dmem_req;  // DMEM priority is simple: if it requests, grant it
    wire imem_can_grant = imem_req && !dmem_has_priority;

    assign arb_imem_sel = imem_can_grant;
    assign imem_grant   = imem_can_grant;
    assign dmem_grant   = dmem_has_priority;
    assign imem_wait    = imem_req && !imem_grant;  // imem requested but not granted
    assign dmem_wait    = dmem_req && !dmem_grant;  // (should not happen; dmem always granted if requested)

endmodule
