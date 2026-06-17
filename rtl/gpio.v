// 8-bit GPIO peripheral
// Reg map (addr[1:0]):
//   0 = OUT  — output data (R/W)
//   1 = IN   — synchronized input (R)
//   2 = DIR  — direction, 1=output (R/W)
//   3 = reserved
module gpio #(
    parameter WIDTH = 8
) (
    input  wire              clk,
    input  wire              rst_n,
    // Bus interface (synchronous — rdata registered, aligned with sel_r in top)
    input  wire              sel,
    input  wire [1:0]        addr,
    input  wire [31:0]       wdata,
    input  wire              we,
    output reg  [31:0]       rdata,
    // Physical pins
    input  wire [WIDTH-1:0]  pin_in,
    output wire [WIDTH-1:0]  pin_out,
    output wire [WIDTH-1:0]  pin_oe
);
    reg [WIDTH-1:0] out_r;
    reg [WIDTH-1:0] dir_r;
    reg [WIDTH-1:0] in_s0, in_s1;   // 2-FF synchronizer

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_r <= {WIDTH{1'b0}};
            dir_r <= {WIDTH{1'b0}};
            in_s0 <= {WIDTH{1'b0}};
            in_s1 <= {WIDTH{1'b0}};
        end else begin
            in_s0 <= pin_in;
            in_s1 <= in_s0;
            if (sel && we)
                case (addr)
                    2'd0: out_r <= wdata[WIDTH-1:0];
                    2'd2: dir_r <= wdata[WIDTH-1:0];
                endcase
        end
    end

    // Registered rdata — matches 1-cycle BRAM latency expected by CPU
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) rdata <= 32'd0;
        else case (addr)
            2'd0:    rdata <= {{(32-WIDTH){1'b0}}, out_r};
            2'd1:    rdata <= {{(32-WIDTH){1'b0}}, in_s1};
            2'd2:    rdata <= {{(32-WIDTH){1'b0}}, dir_r};
            default: rdata <= 32'd0;
        endcase
    end

    assign pin_out = out_r;
    assign pin_oe  = dir_r;
endmodule
