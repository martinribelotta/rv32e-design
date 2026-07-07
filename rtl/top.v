// Top-level for iCE40HX4K LQFP144
//
// Data address space (CPU dmem_addr = byte addr[11:2]; SW base = 0x1000):
//   0x1000-0x17FF  DROM  read-only init ROM  (.rodata + .data load image)
//                        single-port, icebram-patchable (like IMEM)
//   0x1800-0x1EFF  DRAM  writable RAM         (.data runtime + .bss + stack)
//   0x1F00-0x1FFF  peripherals (below):
//   0x3C0  0x1F00  GPIO OUT  (R/W)
//   0x3C1  0x1F04  GPIO IN   (R)
//   0x3C2  0x1F08  GPIO DIR  (R/W, 1=output)
//   0x3D0  0x1F40  UART DATA (W=TX, R=RX — read clears rx_valid)
//   0x3D1  0x1F44  UART STATUS  bit0=tx_ready  bit1=rx_valid
//   0x3D2  0x1F48  UART BAUD    divisor[15:0]  period=(div+1) cycles
//                              default=346 → 115200 baud @ 40 MHz
//   0x3D4  0x1F50  MTIME    [31:0]   (R/W) free-running 64-bit machine timer
//   0x3D5  0x1F54  MTIME    [63:32]
//   0x3D6  0x1F58  MTIMECMP [31:0]   (R/W) timer compare → MTIP when mtime>=cmp
//   0x3D7  0x1F5C  MTIMECMP [63:32]
//
module top (
    input  wire        clk,         // 50 MHz oscillator
    output wire [7:0]  leds,
    input  wire [7:0]  buttons,
    input  wire        uart_rx,
    output wire        uart_tx
);
    localparam IMEM_DEPTH = 1024;  // words (4 KB) instruction memory
    localparam DMEM_DEPTH = 1024;  // words — CPU data address space (10-bit addr)
    localparam DROM_DEPTH = 512;   // words (2 KB) read-only init ROM  (addr[9]==0)
    localparam DRAM_DEPTH = 512;   // words (2 KB) writable RAM         (addr[9]==1)

    // PLL: 50 MHz → 40 MHz
    // F_pfd = 50 / (DIVR+1) = 50 / 5     = 10 MHz
    // VCO   = F_pfd * (DIVF+1) = 10 * 64 = 640 MHz  (533–1066 MHz range)
    // F_out = VCO / 2^DIVQ = 640 / 16    = 40 MHz
    wire clk_core;
    wire pll_lock;

`ifdef SIM_NO_PLL
    // Simulation only: the SB_PLL40_CORE has no behavioural model, so drive the
    // core directly from clk and pulse LOCK low→high once so the reset counter
    // initialises exactly as it does on real hardware after the PLL locks.
    reg sim_lock = 1'b0;
    initial #100 sim_lock = 1'b1;
    assign clk_core = clk;
    assign pll_lock = sim_lock;
`else
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
`endif

    // Reset counter: holds rst_n low for 2048 cycles after PLL locks.
    // pll_lock async-clears the counter so any PLL glitch re-triggers reset.
    reg [11:0] rst_cnt;
    wire rst_n = rst_cnt[11];   // released when MSB reaches 1 (2048 cyc, ~51 µs @ 40 MHz)

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
    wire [31:0] dmem_rdata_mux;   // data read mux (driven at end of module)
    wire        timer_irq;        // machine timer interrupt (mtimer → core)

    rv32e_core #(
        .IMEM_DEPTH (IMEM_DEPTH),
        .DMEM_DEPTH (DMEM_DEPTH)
    ) cpu (
        .clk        (clk_core),
        .rst_n      (rst_n),
        .irq        (1'd0),          // no external interrupt source
        .timer_irq  (timer_irq),     // machine timer (mtimer peripheral)
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
    // Data address decode
    //   drom_sel : dmem_addr[9] == 0    →  0x1000-0x17FF  init ROM (read-only)
    //   dram_sel : dmem_addr[9] == 1    →  0x1800-0x1FFF  RAM (minus I/O)
    //   io_sel   : dmem_addr[9:6] == F  →  0x1F00-0x1FFF  peripherals
    //   gpio_sel : dmem_addr[9:2] == F0 →  0x1F00-0x1F0C
    //   uart_sel : dmem_addr[9:2] == F4 →  0x1F40-0x1F4C
    //   mtmr_sel : dmem_addr[9:2] == F5 →  0x1F50-0x1F5C
    // -------------------------------------------------------
    wire io_sel   = (dmem_addr[9:6] == 4'hF);
    wire drom_sel = (dmem_addr[9] == 1'b0);
    wire dram_sel = (dmem_addr[9] == 1'b1) & ~io_sel;
    wire gpio_sel = (dmem_addr[9:2] == 8'hF0);
    wire uart_sel = (dmem_addr[9:2] == 8'hF4);
    wire mtmr_sel = (dmem_addr[9:2] == 8'hF5);

    wire gpio_we  = gpio_sel & |dmem_we;
    wire uart_we  = uart_sel & |dmem_we;
    wire mtmr_we  = mtmr_sel & |dmem_we;

    // Register sel one cycle to align read mux with registered rdata sources
    reg drom_sel_r, dram_sel_r, gpio_sel_r, uart_sel_r, mtmr_sel_r;
    always @(posedge clk_core or negedge rst_n) begin
        if (!rst_n) begin
            drom_sel_r <= 1'b0;
            dram_sel_r <= 1'b0;
            gpio_sel_r <= 1'b0;
            uart_sel_r <= 1'b0;
            mtmr_sel_r <= 1'b0;
        end else begin
            drom_sel_r <= drom_sel;
            dram_sel_r <= dram_sel;
            gpio_sel_r <= gpio_sel;
            uart_sel_r <= uart_sel;
            mtmr_sel_r <= mtmr_sel;
        end
    end

    // -------------------------------------------------------
    // DROM — read-only init ROM (.rodata + .data load image).
    // Seeded with drom_seed.hex so 'make fw' can patch it via icebram
    // (same single-port flow as IMEM); the CPU never writes here.
    // -------------------------------------------------------
    wire [31:0] drom_rdata;
    imem_rom #(
        .DEPTH    (DROM_DEPTH),
        .INIT_FILE("drom_seed.hex")
    ) drom (
        .clk   (clk_core),
        .addr  (dmem_addr[$clog2(DROM_DEPTH)-1:0]),
        .rdata (drom_rdata)
    );

    // -------------------------------------------------------
    // DRAM — writable data RAM (.data runtime, .bss, stack).
    // Zero-initialised, never icebram-patched. Writes only when dram_sel.
    // -------------------------------------------------------
    wire [3:0]  dram_we = dram_sel ? dmem_we : 4'b0;
    wire [31:0] dram_rdata;
    bram_dp #(
        .DEPTH    (DRAM_DEPTH),
        .INIT_FILE("")
    ) dram (
        .clk     (clk_core),
        .a_addr  ({$clog2(DRAM_DEPTH){1'b0}}),
        .a_rdata (),
        .b_addr  (dmem_addr[$clog2(DRAM_DEPTH)-1:0]),
        .b_wdata (dmem_wdata),
        .b_we    (dram_we),
        .b_rdata (dram_rdata)
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
    // Machine timer (mtime / mtimecmp → timer_irq / MTIP)
    // -------------------------------------------------------
    wire [31:0] mtmr_rdata;

    mtimer mtimer0 (
        .clk       (clk_core),
        .rst_n     (rst_n),
        .sel       (mtmr_sel),
        .addr      (dmem_addr[1:0]),
        .wdata     (dmem_wdata),
        .we        (mtmr_we),
        .rdata     (mtmr_rdata),
        .timer_irq (timer_irq)
    );

    // -------------------------------------------------------
    // Data read mux — all sources have 1-cycle registered latency
    // -------------------------------------------------------
    assign dmem_rdata_mux =
        gpio_sel_r ? gpio_rdata :
        uart_sel_r ? uart_rdata :
        mtmr_sel_r ? mtmr_rdata :
        drom_sel_r ? drom_rdata :
                     dram_rdata;

endmodule
