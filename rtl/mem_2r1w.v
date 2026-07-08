// Unified instruction + data memory: 2 read ports + 1 write port (2R1W).
//
//   Read port 0  (i_addr / i_rdata)              : instruction fetch — read-only
//   Read/Write 1 (d_addr / d_wdata / d_we / d_rdata): data
//
// On iCE40 an SB_RAM40_4K tile is physically 1R + 1W, so a genuine 2R1W is built
// by giving each read port its own bank rather than a single shared array:
//   - the instruction path is a write-free bank (IMEM), so Yosys maps it to a
//     SYMMETRIC tile and it stays icebram-patchable (the fast `make fw` flow);
//   - the data path keeps the existing ROM/RAM split.
// A byte-writable bank would map to ASYMMETRIC tiles and break icebram
// (see docs/architecture.md), which is why instructions live in their own ROM.
//
// Data address space (word address; high bit selects the bank):
//   d_addr[MSB]==0  -> DROM  (0x1000-0x17FF)  read-only init image (.rodata + .data LMA)
//   d_addr[MSB]==1  -> DRAM  (0x1800-0x1FFF)  writable RAM (.data runtime, .bss, stack)
// Writes (d_we) are pre-gated by the caller to the DRAM region only; DROM is
// read-only and the peripheral window is excluded upstream.
//
// This module is a thin structural wrapper over the proven imem_rom (ROM) and
// bram_dp (byte-writable RAM) blocks, so its BRAM mapping and icebram behaviour
// match the previous discrete instantiation exactly.
module mem_2r1w #(
    parameter IMEM_DEPTH = 1024,             // code words     (0x0000-0x0FFF)
    parameter DROM_DEPTH = 512,              // rodata/.data    (0x1000-0x17FF)
    parameter DRAM_DEPTH = 512,              // writable RAM    (0x1800-0x1EFF)
    parameter IMEM_INIT  = "imem_seed.hex",
    parameter DROM_INIT  = "drom_seed.hex"
) (
    input  wire                            clk,
    input  wire                            rst_n,
    // Read port 0 — instruction fetch (read-only, icebram-patchable ROM)
    input  wire [$clog2(IMEM_DEPTH)-1:0]   i_addr,
    output wire [31:0]                     i_rdata,
    // Read/Write port 1 — data (byte-enabled write)
    input  wire [$clog2(DROM_DEPTH+DRAM_DEPTH)-1:0] d_addr,
    input  wire [31:0]                     d_wdata,
    input  wire [3:0]                      d_we,
    output wire [31:0]                     d_rdata
);
    localparam DROM_AW = $clog2(DROM_DEPTH);
    localparam DRAM_AW = $clog2(DRAM_DEPTH);
    localparam DATA_AW = $clog2(DROM_DEPTH+DRAM_DEPTH);   // = max(DROM_AW,DRAM_AW)+1

    // Bank select: high data-address bit chooses DRAM (1) vs DROM (0).
    wire drom_sel = (d_addr[DATA_AW-1] == 1'b0);

    // ---- Read port 0: instruction ROM (write-free -> symmetric, icebram) ----
    imem_rom #(
        .DEPTH    (IMEM_DEPTH),
        .INIT_FILE(IMEM_INIT)
    ) imem (
        .clk   (clk),
        .addr  (i_addr),
        .rdata (i_rdata)
    );

    // ---- Read port 1a: data init ROM (write-free -> symmetric, icebram) ----
    wire [31:0] drom_rdata;
    imem_rom #(
        .DEPTH    (DROM_DEPTH),
        .INIT_FILE(DROM_INIT)
    ) drom (
        .clk   (clk),
        .addr  (d_addr[DROM_AW-1:0]),
        .rdata (drom_rdata)
    );

    // ---- Read/Write port 1b: writable data RAM (byte enables) ----
    // Port A of bram_dp is unused here; only port B (read/write) drives the data
    // path. d_we is already gated to the DRAM region by the caller.
    wire [31:0] dram_rdata;
    bram_dp #(
        .DEPTH    (DRAM_DEPTH),
        .INIT_FILE("")
    ) dram (
        .clk     (clk),
        .a_addr  ({DRAM_AW{1'b0}}),
        .a_rdata (),
        .b_addr  (d_addr[DRAM_AW-1:0]),
        .b_wdata (d_wdata),
        .b_we    (d_we),
        .b_rdata (dram_rdata)
    );

    // Registered bank select aligns with the 1-cycle registered BRAM output.
    reg drom_sel_r;
    always @(posedge clk or negedge rst_n)
        if (!rst_n) drom_sel_r <= 1'b0;
        else        drom_sel_r <= drom_sel;

    assign d_rdata = drom_sel_r ? drom_rdata : dram_rdata;
endmodule
