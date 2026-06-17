// Top-level for iCE40HX4K LQFP144
//
// Peripheral bus — DMEM word addresses (SW byte addresses: base DMEM = 0x1000):
//   0x3C0  0x1F00  GPIO OUT  (R/W)
//   0x3C1  0x1F04  GPIO IN   (R)
//   0x3C2  0x1F08  GPIO DIR  (R/W, 1=output)
//   0x3D0  0x1F40  UART DATA (W=TX, R=RX — read clears rx_valid)
//   0x3D1  0x1F44  UART STATUS  bit0=tx_ready  bit1=rx_valid
//   0x3D2  0x1F48  UART BAUD    divisor[15:0]  period=(div+1) cycles
//                              default=346 → 115200 baud @ 40 MHz
//
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

    // -------------------------------------------------------
    // CPU ports
    // -------------------------------------------------------
    wire [$clog2(IMEM_DEPTH)-1:0] imem_addr;
    wire [31:0] imem_rdata;
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

    // -------------------------------------------------------
    // Instruction ROM (seed → replaced by 'make fw' via icebram)
    // -------------------------------------------------------
    imem_rom #(
        .DEPTH    (IMEM_DEPTH),
        .INIT_FILE("imem_seed.hex")
    ) imem (
        .clk   (clk_core),
        .addr  (imem_addr),
        .rdata (imem_rdata)
    );

    // -------------------------------------------------------
    // Peripheral address decode
    //   io_sel   : dmem_addr[9:6] == 4'hF  →  0x3C0-0x3FF
    //   gpio_sel : dmem_addr[9:2] == 8'hF0 →  0x3C0-0x3C3
    //   uart_sel : dmem_addr[9:2] == 8'hF4 →  0x3D0-0x3D3
    // -------------------------------------------------------
    wire io_sel   = (dmem_addr[9:6] == 4'hF);
    wire gpio_sel = (dmem_addr[9:2] == 8'hF0);
    wire uart_sel = (dmem_addr[9:2] == 8'hF4);

    wire gpio_we  = gpio_sel & |dmem_we;
    wire uart_we  = uart_sel & |dmem_we;

    // Register sel one cycle to align read mux with registered peripheral rdata
    reg gpio_sel_r, uart_sel_r;
    always @(posedge clk_core or negedge rst_n) begin
        if (!rst_n) begin
            gpio_sel_r <= 1'b0;
            uart_sel_r <= 1'b0;
        end else begin
            gpio_sel_r <= gpio_sel;
            uart_sel_r <= uart_sel;
        end
    end

    // -------------------------------------------------------
    // Data BRAM — writes to I/O range are blocked
    // -------------------------------------------------------
    wire [3:0] dmem_we_ram = io_sel ? 4'b0 : dmem_we;

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

    // -------------------------------------------------------
    // GPIO peripheral
    // pin_out → leds (PCF: always-output pins)
    // pin_in  ← buttons (PCF: always-input pins)
    // -------------------------------------------------------
    wire [31:0] gpio_rdata;
    wire [7:0]  gpio_pin_out;
    wire [7:0]  gpio_pin_oe;   // available for future SB_IO expansion

    gpio #(.WIDTH(8)) gpio0 (
        .clk     (clk_core),
        .rst_n   (rst_n),
        .sel     (gpio_sel),
        .addr    (dmem_addr[1:0]),
        .wdata   (dmem_wdata),
        .we      (gpio_we),
        .rdata   (gpio_rdata),
        .pin_in  (buttons),
        .pin_out (gpio_pin_out),
        .pin_oe  (gpio_pin_oe)
    );

    assign leds = gpio_pin_out;

    // -------------------------------------------------------
    // UART peripheral
    // -------------------------------------------------------
    wire [31:0] uart_rdata;

    uart #(
        .CLK_FREQ  (40_000_000),
        .BAUD_RATE (115_200)
    ) uart0 (
        .clk   (clk_core),
        .rst_n (rst_n),
        .sel   (uart_sel),
        .addr  (dmem_addr[1:0]),
        .wdata (dmem_wdata),
        .we    (uart_we),
        .rdata (uart_rdata),
        .rx    (uart_rx),
        .tx    (uart_tx)
    );

    // -------------------------------------------------------
    // DMEM read mux — all sources have 1-cycle registered latency
    // -------------------------------------------------------
    wire [31:0] dmem_rdata_mux =
        gpio_sel_r ? gpio_rdata :
        uart_sel_r ? uart_rdata :
        dmem_rdata;

endmodule
