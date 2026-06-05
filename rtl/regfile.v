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
    reg [31:0] regs [1:15];

    integer i;
    initial begin
        for (i = 1; i < 16; i = i + 1)
            regs[i] = 32'd0;
    end

    assign rdata1 = (rs1 == 4'd0) ? 32'd0 : regs[rs1];
    assign rdata2 = (rs2 == 4'd0) ? 32'd0 : regs[rs2];

    always @(posedge clk)
        if (we && rd != 4'd0)
            regs[rd] <= wdata;
endmodule
