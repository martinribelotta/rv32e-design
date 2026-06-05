// Top-level for iCE40HX4K LQFP144
module top (
    input  wire clk,       // 50 MHz oscillator
    input  wire rst_n_in,
    output wire led        // heartbeat
);
    localparam IMEM_DEPTH = 1024;  // words (4 KB) — 8 EBRs on HX4K
    localparam DMEM_DEPTH = 1024;  // words (4 KB) — 8 EBRs on HX4K

    // PLL: 50 MHz → 40 MHz
    // F_pfd = 50 / (DIVR+1) = 50 / 5     = 10 MHz
    // VCO   = F_pfd * (DIVF+1) = 10 * 64 = 640 MHz  (in 533–1066 MHz range)
    // F_out = VCO / 2^DIVQ = 640 / 16    = 40 MHz
    wire clk_core;
    wire pll_lock;

    SB_PLL40_CORE #(
        .FEEDBACK_PATH ("SIMPLE"),
        .DIVR          (4'd4),
        .DIVF          (7'd63),
        .DIVQ          (3'd4),
        .FILTER_RANGE  (3'b001)
    ) pll (
        .REFERENCECLK  (clk),
        .PLLOUTGLOBAL  (clk_core),
        .LOCK          (pll_lock),
        .RESETB        (1'b1),
        .BYPASS        (1'b0)
    );

    // Reset synchronizer: hold reset while PLL is unlocked or board reset active.
    // Uses pll_lock as async clear so the pipeline stays in reset until the
    // clock is stable.
    reg [2:0] rst_sr;
    always @(posedge clk_core or negedge pll_lock)
        if (!pll_lock) rst_sr <= 3'b000;
        else           rst_sr <= {rst_sr[1:0], rst_n_in};
    wire rst_n = rst_sr[2];

    // Instruction memory wires
    wire [$clog2(IMEM_DEPTH)-1:0] imem_addr;
    wire [31:0] imem_rdata;

    // Data memory wires
    wire [$clog2(DMEM_DEPTH)-1:0] dmem_addr;
    wire [31:0] dmem_wdata;
    wire [3:0]  dmem_we;
    wire [31:0] dmem_rdata;

    rv32i_core #(
        .IMEM_DEPTH (IMEM_DEPTH),
        .DMEM_DEPTH (DMEM_DEPTH)
    ) cpu (
        .clk        (clk_core),
        .rst_n      (rst_n),
        .imem_addr  (imem_addr),
        .imem_rdata (imem_rdata),
        .dmem_addr  (dmem_addr),
        .dmem_wdata (dmem_wdata),
        .dmem_we    (dmem_we),
        .dmem_rdata (dmem_rdata)
    );

    // Instruction BRAM (read-only port A used by CPU fetch)
    bram_dp #(
        .INIT_FILE("firmware.hex")
    ) imem (
        .clk     (clk_core),
        .a_addr  (imem_addr),
        .a_rdata (imem_rdata),
        .b_addr  (10'd0),
        .b_wdata (32'd0),
        .b_we    (4'd0),
        .b_rdata ()
    );

    // Memory-mapped I/O: address 0x3FF (last word) is an output register.
    // CPU writes bit[0] to control the LED.
    wire       io_sel      = (dmem_addr == 10'h3FF);
    wire [3:0] dmem_we_ram = io_sel ? 4'b0 : dmem_we;

    // Data BRAM
    bram_dp #(
        .INIT_FILE("data.hex")
    ) dmem (
        .clk     (clk_core),
        .a_addr  (10'd0),
        .a_rdata (),
        .b_addr  (dmem_addr),
        .b_wdata (dmem_wdata),
        .b_we    (dmem_we_ram),
        .b_rdata (dmem_rdata)
    );

    // LED register: written by CPU via memory-mapped I/O at 0x3FF
    reg io_led;
    always @(posedge clk_core or negedge rst_n)
        if (!rst_n)               io_led <= 1'b0;
        else if (io_sel && |dmem_we) io_led <= dmem_wdata[0];
    assign led = io_led;

endmodule
