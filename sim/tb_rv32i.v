`timescale 1ns/1ps
`include "../rtl/rv32i_pkg.v"

module tb_rv32i;
    reg clk, rst_n;

    localparam IMEM_DEPTH = 1024;
    localparam DMEM_DEPTH = 1024;

    wire [$clog2(IMEM_DEPTH)-1:0] imem_addr;
    wire [31:0] imem_rdata;
    wire [$clog2(DMEM_DEPTH)-1:0] dmem_addr;
    wire [31:0] dmem_wdata;
    wire [3:0]  dmem_we;
    wire [31:0] dmem_rdata;

    rv32i_core #(
        .IMEM_DEPTH (IMEM_DEPTH),
        .DMEM_DEPTH (DMEM_DEPTH)
    ) dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .imem_addr  (imem_addr),
        .imem_rdata (imem_rdata),
        .dmem_addr  (dmem_addr),
        .dmem_wdata (dmem_wdata),
        .dmem_we    (dmem_we),
        .dmem_rdata (dmem_rdata)
    );

    bram_dp #(.INIT_FILE("firmware.hex")) imem (
        .clk(clk), .a_addr(imem_addr), .a_rdata(imem_rdata),
        .b_addr(10'd0), .b_wdata(32'd0), .b_we(4'd0), .b_rdata()
    );

    bram_dp #(.INIT_FILE("data.hex")) dmem (
        .clk(clk), .a_addr(10'd0), .a_rdata(),
        .b_addr(dmem_addr), .b_wdata(dmem_wdata), .b_we(dmem_we), .b_rdata(dmem_rdata)
    );

    initial clk = 0;
    always #5 clk = ~clk; // 100 MHz sim clock

    integer i;
    initial begin
        $dumpfile("tb_rv32i.vcd");
        $dumpvars(0, tb_rv32i);
        rst_n = 0;
        repeat(4) @(posedge clk);
        rst_n = 1;
        repeat(2000) @(posedge clk);
        $display("--- Register dump ---");
        for (i = 0; i < 32; i = i + 1)
            $display("x%02d = %08h", i, (i == 0) ? 32'd0 : dut.rf.regs[i]);
        $finish;
    end
endmodule
