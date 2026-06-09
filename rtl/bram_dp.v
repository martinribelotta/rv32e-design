// True dual-port BRAM 1Kx32 (inferred for iCE40)
module bram_dp #(
    parameter DEPTH = 1024,
    parameter WIDTH = 32,
    parameter INIT_FILE = ""
) (
    input  wire             clk,
    // Port A (instruction fetch - read only)
    input  wire [$clog2(DEPTH)-1:0] a_addr,
    output reg  [WIDTH-1:0]         a_rdata,
    // Port B (data - read/write)
    input  wire [$clog2(DEPTH)-1:0] b_addr,
    input  wire [WIDTH-1:0]         b_wdata,
    input  wire [3:0]               b_we,
    output reg  [WIDTH-1:0]         b_rdata
);
    (* ram_style = "block" *) reg [WIDTH-1:0] mem [0:DEPTH-1];

    integer i;
    initial begin
        for (i = 0; i < DEPTH; i = i + 1)
            mem[i] = 32'h0;
        if (INIT_FILE != "")
            $readmemh(INIT_FILE, mem);
    end

    // Port A - synchronous read
    always @(posedge clk)
        a_rdata <= mem[a_addr];

    // Port B - synchronous read/write with byte enables
    always @(posedge clk) begin
        if (b_we[0]) mem[b_addr][ 7: 0] <= b_wdata[ 7: 0];
        if (b_we[1]) mem[b_addr][15: 8] <= b_wdata[15: 8];
        if (b_we[2]) mem[b_addr][23:16] <= b_wdata[23:16];
        if (b_we[3]) mem[b_addr][31:24] <= b_wdata[31:24];
        b_rdata <= mem[b_addr];
    end
endmodule
