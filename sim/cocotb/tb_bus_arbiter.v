// Testbench for bus arbitrator + wait state controller
// Instantiates rv32e_core with bus arbiter and wait controller

`include "rv32e_pkg.v"

module tb_bus_arbiter #(
    parameter CLK_PERIOD_NS = 10
) (
    output reg         clk,
    output reg         rst_n,
    input  wire        irq,
    input  wire        timer_irq,
    output wire [9:0]  imem_addr,
    output wire [9:0]  dmem_addr,
    output wire [31:0] dmem_wdata,
    output wire [3:0]  dmem_we,
    output wire [31:0] imem_rdata,
    output wire [31:0] dmem_rdata,
    output wire        bus_wait,
    output wire        imem_wait,
    output wire        dmem_wait
);

    // Clock generator
    initial begin
        clk = 0;
        forever #(CLK_PERIOD_NS/2) clk = ~clk;
    end

    // Reset sequence
    initial begin
        rst_n = 0;
        #100;
        rst_n = 1;
    end

    localparam IMEM_DEPTH = 1024;
    localparam DMEM_DEPTH = 1024;

    // Internal signals
    wire [9:0]  cpu_imem_addr;
    reg  [31:0] cpu_imem_rdata;
    wire [9:0]  cpu_dmem_addr;
    wire [31:0] cpu_dmem_wdata;
    wire [3:0]  cpu_dmem_we;
    reg  [31:0] cpu_dmem_rdata;

    // Arbitrator signals
    wire imem_req = 1'b1;
    wire dmem_req = |cpu_dmem_we;
    wire imem_grant, dmem_grant;


    // Instantiate CPU
    rv32e_core #(
        .IMEM_DEPTH(IMEM_DEPTH),
        .DMEM_DEPTH(DMEM_DEPTH)
    ) cpu (
        .clk        (clk),
        .rst_n      (rst_n),
        .irq        (irq),
        .timer_irq  (timer_irq),
        .bus_wait   (bus_wait),
        .imem_addr  (cpu_imem_addr),
        .imem_rdata (cpu_imem_rdata),
        .dmem_addr  (cpu_dmem_addr),
        .dmem_wdata (cpu_dmem_wdata),
        .dmem_we    (cpu_dmem_we),
        .dmem_rdata (cpu_dmem_rdata)
    );

    // Bus arbitrator
    bus_arbiter arb (
        .clk          (clk),
        .rst_n        (rst_n),
        .imem_req     (imem_req),
        .imem_grant   (imem_grant),
        .imem_wait    (imem_wait),
        .dmem_req     (dmem_req),
        .dmem_grant   (dmem_grant),
        .dmem_wait    (dmem_wait),
        .arb_imem_sel ()
    );

    // Wait state controller
    bus_wait_ctrl #(
        .WAIT_CYCLES(1)
    ) wait_ctrl (
        .clk          (clk),
        .rst_n        (rst_n),
        .imem_wait_i  (imem_wait),
        .dmem_wait_i  (dmem_wait),
        .cpu_wait_o   (bus_wait),
        .wait_cnt     ()
    );

    // Memory arrays
    reg [31:0] imem_array [0:IMEM_DEPTH-1];
    reg [31:0] dmem_array [0:DMEM_DEPTH-1];

    // IMEM read
    always @(posedge clk) begin
        cpu_imem_rdata <= imem_array[cpu_imem_addr];
    end

    // DMEM read/write
    always @(posedge clk) begin
        if (cpu_dmem_we[0]) dmem_array[cpu_dmem_addr][7:0]   <= cpu_dmem_wdata[7:0];
        if (cpu_dmem_we[1]) dmem_array[cpu_dmem_addr][15:8]  <= cpu_dmem_wdata[15:8];
        if (cpu_dmem_we[2]) dmem_array[cpu_dmem_addr][23:16] <= cpu_dmem_wdata[23:16];
        if (cpu_dmem_we[3]) dmem_array[cpu_dmem_addr][31:24] <= cpu_dmem_wdata[31:24];
        cpu_dmem_rdata <= dmem_array[cpu_dmem_addr];
    end

    // Debug outputs
    assign imem_addr  = cpu_imem_addr;
    assign dmem_addr  = cpu_dmem_addr;
    assign dmem_wdata = cpu_dmem_wdata;
    assign dmem_we    = cpu_dmem_we;
    assign imem_rdata = cpu_imem_rdata;
    assign dmem_rdata = cpu_dmem_rdata;

endmodule
