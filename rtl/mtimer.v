// RISC-V machine timer (CLINT-style mtime / mtimecmp)
// Reg map (addr[1:0], word offsets from 0x1F50):
//   0 = MTIME_LO    — mtime[31:0]     (R/W)
//   1 = MTIME_HI    — mtime[63:32]    (R/W)
//   2 = MTIMECMP_LO — mtimecmp[31:0]  (R/W)
//   3 = MTIMECMP_HI — mtimecmp[63:32] (R/W)
//
// mtime is a free-running 64-bit counter (one tick per clk). timer_irq is
// asserted while mtime >= mtimecmp and feeds the core's machine timer
// interrupt (MTIP). Firmware re-arms by writing a larger mtimecmp.
module mtimer (
    input  wire        clk,
    input  wire        rst_n,
    // Bus interface (synchronous rdata — aligned with sel_r in top)
    input  wire        sel,
    input  wire [1:0]  addr,
    input  wire [31:0] wdata,
    input  wire        we,
    output reg  [31:0] rdata,
    // Machine timer interrupt request (level, registered)
    output reg         timer_irq
);
    reg [63:0] mtime;
    reg [63:0] mtimecmp;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mtime    <= 64'd0;
            mtimecmp <= 64'hFFFF_FFFF_FFFF_FFFF;  // no match until configured
        end else begin
            mtime <= mtime + 64'd1;
            if (sel && we) begin
                case (addr)
                    2'd0: mtime[31:0]     <= wdata;
                    2'd1: mtime[63:32]    <= wdata;
                    2'd2: mtimecmp[31:0]  <= wdata;
                    2'd3: mtimecmp[63:32] <= wdata;
                endcase
            end
        end
    end

    // Registered compare: gives the 64-bit comparator a full cycle and is
    // re-synchronised inside the core, so the extra cycle of latency is benign.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) timer_irq <= 1'b0;
        else        timer_irq <= (mtime >= mtimecmp);
    end

    // Registered rdata — matches 1-cycle BRAM latency expected by the CPU
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) rdata <= 32'd0;
        else case (addr)
            2'd0:    rdata <= mtime[31:0];
            2'd1:    rdata <= mtime[63:32];
            2'd2:    rdata <= mtimecmp[31:0];
            2'd3:    rdata <= mtimecmp[63:32];
            default: rdata <= 32'd0;
        endcase
    end
endmodule
