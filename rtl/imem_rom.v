// Single-port synchronous ROM for instruction fetch.
// No write port: Yosys maps this as SB_RAM40_4K with matching READ/WRITE modes,
// allowing ICE40_BRAMINIT to correctly propagate $readmemh init to INIT_0..F.
// That is required for the icebram fast firmware-update flow (make fw).
module imem_rom #(
    parameter DEPTH     = 1024,
    parameter INIT_FILE = "imem_seed.hex"
) (
    input  wire                      clk,
    input  wire [$clog2(DEPTH)-1:0]  addr,
    output reg  [31:0]               rdata
);
    (* ram_style = "block" *) reg [31:0] mem [0:DEPTH-1];

    initial
        if (INIT_FILE != "") $readmemh(INIT_FILE, mem);

    always @(posedge clk)
        rdata <= mem[addr];
endmodule
