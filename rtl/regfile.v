// Register file — synchronous read so Yosys can infer BRAM (SB_RAM40_4K).
//
// Timing contract (Option-B pipeline):
//   rs1/rs2 are presented ONE cycle before the data is needed (during IF stage).
//   rdata1/rdata2 are valid the following cycle (during ID/EX stage).
//
// WB bypass: when MEM/WB writes register rd at the same cycle that IF presents
//   the same address to the BRAM read port, the BRAM returns the OLD value.
//   The bypass registers capture the write and override the stale output.
module regfile (
    input  wire        clk,
    input  wire        we,
    input  wire [3:0]  rs1,
    input  wire [3:0]  rs2,
    input  wire [3:0]  rd,
    input  wire [31:0] wdata,
    output wire [31:0] rdata1,
    output wire [31:0] rdata2
);
    // x0 is stored as 0 and never written (guard: we && rd!=0).
    (* ram_style = "block" *) reg [31:0] regs [0:15];

    integer k;
    initial begin
        for (k = 0; k < 16; k = k + 1)
            regs[k] = 32'd0;
    end

    // Synchronous read — inferred as BRAM
    reg [31:0] bram_r1, bram_r2;
    always @(posedge clk) begin
        bram_r1 <= regs[rs1];
        bram_r2 <= regs[rs2];
    end

    // Write port (never writes x0)
    always @(posedge clk)
        if (we && rd != 4'd0)
            regs[rd] <= wdata;

    // Bypass: capture WB write at the same cycle IF presents the read address.
    // One cycle later the BRAM output would be stale; override it.
    reg        byp1_en,   byp2_en;
    reg [31:0] byp1_data, byp2_data;
    always @(posedge clk) begin
        byp1_en   <= we && (rd != 4'd0) && (rd == rs1);
        byp1_data <= wdata;
        byp2_en   <= we && (rd != 4'd0) && (rd == rs2);
        byp2_data <= wdata;
    end

    assign rdata1 = byp1_en ? byp1_data : bram_r1;
    assign rdata2 = byp2_en ? byp2_data : bram_r2;

endmodule
