// Bus Wait State Controller: manages wait state insertion for CPU pipeline stall.
//
// This module takes arbiter wait signals and generates a programmable number of
// wait cycles. If back-to-back conflicts occur, wait states accumulate.
//
// Features:
//   - Configurable wait-cycle count per conflict (default: 1 cycle per stall)
//   - Tracks both IMEM and DMEM contention separately
//   - Outputs combined stall signal to CPU (freezes pipeline)
//
module bus_wait_ctrl #(
    parameter WAIT_CYCLES = 1  // number of wait cycles per conflict
) (
    input  wire clk,
    input  wire rst_n,

    // From arbiter
    input  wire imem_wait_i,
    input  wire dmem_wait_i,

    // CPU stall output
    output wire cpu_wait_o,    // asserted when bus has pending wait cycles

    // Status (optional monitoring)
    output wire [3:0] wait_cnt  // number of remaining wait cycles
);

    // Wait counter: counts down from WAIT_CYCLES when conflict detected
    reg [3:0] wait_counter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wait_counter <= 4'd0;
        end else begin
            // If a new conflict arrives and counter is idle, preload counter
            if ((imem_wait_i || dmem_wait_i) && (wait_counter == 4'd0)) begin
                wait_counter <= WAIT_CYCLES[3:0];
            end
            // Otherwise, decrement if running
            else if (wait_counter > 4'd0) begin
                wait_counter <= wait_counter - 4'd1;
            end
        end
    end

    // Assert stall when wait counter is active
    assign cpu_wait_o = (wait_counter > 4'd0);
    assign wait_cnt   = wait_counter;

endmodule
