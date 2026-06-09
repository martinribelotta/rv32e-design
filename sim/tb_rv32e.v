`timescale 1ns/1ps
`include "../rtl/rv32e_pkg.v"

module tb_rv32e;
    reg clk, rst_n;

    localparam IMEM_DEPTH = 1024;
    localparam DMEM_DEPTH = 1024;
    // tohost is the last word of DMEM (byte address 0x1FFC → word 1023)
    localparam TOHOST_WORD = DMEM_DEPTH - 1;

    wire [$clog2(IMEM_DEPTH)-1:0] imem_addr;
    wire [31:0] imem_rdata;
    wire [$clog2(DMEM_DEPTH)-1:0] dmem_addr;
    wire [31:0] dmem_wdata;
    wire [3:0]  dmem_we;
    wire [31:0] dmem_rdata;
    reg         irq;

    rv32e_core #(
        .IMEM_DEPTH (IMEM_DEPTH),
        .DMEM_DEPTH (DMEM_DEPTH)
    ) dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .irq        (irq),
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
    always #5 clk = ~clk;

    // -------------------------------------------------------
    // tohost monitor: watch for SW to DMEM word 0
    // tohost = 1         → PASS
    // tohost = (n<<1)|1  → FAIL at test n
    // -------------------------------------------------------
    integer exit_code;
    initial exit_code = -1;

    integer cycle;

    always @(posedge clk) begin
        if (rst_n && |dmem_we && dmem_addr == TOHOST_WORD) begin
            exit_code = dmem_wdata;
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            irq <= 1'b0;
        end else if (cycle == 20) begin
            irq <= 1'b1;
        end else begin
            irq <= 1'b0;
        end
    end

    // -------------------------------------------------------
    // Run up to MAX_CYCLES then report
    // -------------------------------------------------------
    localparam MAX_CYCLES = 50000;
    initial begin
        $dumpfile("tb_rv32e.vcd");
        $dumpvars(0, tb_rv32e);
        rst_n = 0;
        irq = 0;
        repeat(4) @(posedge clk);
        rst_n = 1;

        for (cycle = 0; cycle < MAX_CYCLES; cycle = cycle + 1) begin
            @(posedge clk);
            if (exit_code != -1) begin
                if (exit_code == 1) begin
                    $display("PASS");
                end else begin
                    $display("FAIL (test %0d)", exit_code >> 1);
                end
                $finish;
            end
        end

        $display("TIMEOUT after %0d cycles", MAX_CYCLES);
        $finish;
    end
endmodule
