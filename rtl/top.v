// Top-level for iCE40HX4K LQFP144
module top (
    input  wire        clk,         // 50 MHz oscillator
    output wire [7:0]  leds,
    input  wire [7:0]  buttons,
    input  wire        uart_rx,
    output wire        uart_tx
);
    localparam IMEM_DEPTH = 1024;  // words (4 KB)
    localparam DMEM_DEPTH = 1024;  // words (4 KB)

    // PLL: 50 MHz → 40 MHz
    // F_pfd = 50 / (DIVR+1) = 50 / 5     = 10 MHz
    // VCO   = F_pfd * (DIVF+1) = 10 * 64 = 640 MHz  (533–1066 MHz range)
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

    // Reset counter: holds rst_n low for 4096 cycles after PLL locks.
    // pll_lock async-clears the counter so any PLL glitch re-triggers reset.
    reg [11:0] rst_cnt;
    wire rst_n = rst_cnt[11];   // released when MSB reaches 1 (~102 µs @ 40 MHz)

    always @(posedge clk_core or negedge pll_lock)
        if (!pll_lock)  rst_cnt <= 12'd0;
        else if (!rst_n) rst_cnt <= rst_cnt + 12'd1;

    // Instruction memory wires
    wire [$clog2(IMEM_DEPTH)-1:0] imem_addr;
    wire [31:0] imem_rdata;

    // Data memory wires
    wire [$clog2(DMEM_DEPTH)-1:0] dmem_addr;
    wire [31:0] dmem_wdata;
    wire [3:0]  dmem_we;
    wire [31:0] dmem_rdata;

    rv32e_core #(
        .IMEM_DEPTH (IMEM_DEPTH),
        .DMEM_DEPTH (DMEM_DEPTH)
    ) cpu (
        .clk        (clk_core),
        .rst_n      (rst_n),
        .irq        (1'd0),
        .imem_addr  (imem_addr),
        .imem_rdata (imem_rdata),
        .dmem_addr  (dmem_addr),
        .dmem_wdata (dmem_wdata),
        .dmem_we    (dmem_we),
        .dmem_rdata (dmem_rdata_mux)
    );

    // Instruction ROM (read-only fetch).
    // Synthesised with a random seed (imem_seed.hex) so icebram can identify
    // IMEM tiles uniquely. Real firmware is patched in via 'make fw'.
    imem_rom #(
        .DEPTH    (IMEM_DEPTH),
        .INIT_FILE("imem_seed.hex")
    ) imem (
        .clk   (clk_core),
        .addr  (imem_addr),
        .rdata (imem_rdata)
    );

    // Memory-mapped I/O (word addresses in DMEM):
    //   0x3F8  buttons[7:0]  (read)
    //   0x3FF  leds[7:0]     (write)
    wire io_sel_led     = (dmem_addr == 10'h3FF);
    wire io_sel_buttons = (dmem_addr == 10'h3F8);
    wire [3:0] dmem_we_ram = (io_sel_led | io_sel_buttons) ? 4'b0 : dmem_we;

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

    // LED register: written at 0x3FF, bits[7:0]
    reg [7:0] io_led;
    always @(posedge clk_core or negedge rst_n)
        if (!rst_n)                      io_led <= 8'h00;
        else if (io_sel_led && |dmem_we) io_led <= dmem_wdata[7:0];
    assign leds = io_led;

    // Buttons read mux: BRAM output is registered (synchronous), so register
    // io_sel_buttons one cycle to align with when b_rdata is valid.
    reg io_sel_buttons_r;
    always @(posedge clk_core or negedge rst_n)
        if (!rst_n) io_sel_buttons_r <= 1'b0;
        else        io_sel_buttons_r <= io_sel_buttons;

    wire [31:0] dmem_rdata_mux = io_sel_buttons_r ? {24'b0, buttons} : dmem_rdata;

    // UART passthrough placeholder
    assign uart_tx = uart_rx;

endmodule
