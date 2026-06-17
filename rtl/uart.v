// 8N1 UART peripheral
// Reg map (addr[1:0]):
//   0 = DATA   — write: TX byte (dropped if busy); read: RX byte (clears rx_valid)
//   1 = STATUS — bit0=tx_ready, bit1=rx_valid  (read-only)
//   2 = BAUD   — baud divisor [15:0], period = (divisor+1) cycles  (R/W)
//   3 = reserved
module uart #(
    parameter CLK_FREQ  = 40_000_000,
    parameter BAUD_RATE = 115_200
) (
    input  wire        clk,
    input  wire        rst_n,
    // Bus interface (synchronous rdata — aligned with sel_r in top)
    input  wire        sel,
    input  wire [1:0]  addr,
    input  wire [31:0] wdata,
    input  wire        we,
    output reg  [31:0] rdata,
    // UART pins
    input  wire        rx,
    output reg         tx
);
    localparam [15:0] BAUD_DIV_DEF = CLK_FREQ / BAUD_RATE - 1;

    reg [15:0] baud_div;

    // -------------------------------------------------------
    // TX — shift register, 10 bits: {stop=1, d7..d0, start=0}
    // -------------------------------------------------------
    reg [9:0]  tx_sr;
    reg [3:0]  tx_bits;   // bits remaining (0 = idle)
    reg [15:0] tx_cnt;

    wire tx_idle = (tx_bits == 4'd0);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx      <= 1'b1;
            tx_sr   <= 10'h3FF;
            tx_bits <= 4'd0;
            tx_cnt  <= 16'd0;
        end else if (tx_idle) begin
            tx <= 1'b1;
            if (sel && we && addr == 2'd0) begin
                // Load frame: {stop, data[7:0], start}
                tx_sr   <= {1'b1, wdata[7:0], 1'b0};
                tx      <= 1'b0;        // start bit immediately
                tx_bits <= 4'd10;
                tx_cnt  <= baud_div;
            end
        end else if (tx_cnt == 16'd0) begin
            // Advance to next bit: shift right, filling 1s from MSB
            tx_sr   <= {1'b1, tx_sr[9:1]};
            tx      <= tx_sr[1];        // bit that will be at [0] after shift
            tx_bits <= tx_bits - 4'd1;
            tx_cnt  <= baud_div;
        end else begin
            tx_cnt <= tx_cnt - 16'd1;
        end
    end

    // -------------------------------------------------------
    // RX — 4-state FSM: IDLE → START (half-baud) → DATA → STOP
    // -------------------------------------------------------
    reg [1:0]  rx_sync;
    wire       rx_s      = rx_sync[1];
    reg        rx_s_prev;

    localparam RX_IDLE  = 2'd0;
    localparam RX_START = 2'd1;
    localparam RX_DATA  = 2'd2;
    localparam RX_STOP  = 2'd3;

    reg [1:0]  rx_state;
    reg [2:0]  rx_bit;
    reg [7:0]  rx_sr;
    reg [15:0] rx_cnt;
    reg        rx_valid;
    reg [7:0]  rx_data_r;

    // 2-FF synchronizer
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) rx_sync <= 2'b11;
        else        rx_sync <= {rx_sync[0], rx};
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) rx_s_prev <= 1'b1;
        else        rx_s_prev <= rx_s;
    end

    // Baud divisor register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)                       baud_div <= BAUD_DIV_DEF;
        else if (sel && we && addr == 2'd2) baud_div <= wdata[15:0];
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_state  <= RX_IDLE;
            rx_bit    <= 3'd0;
            rx_sr     <= 8'd0;
            rx_cnt    <= 16'd0;
            rx_valid  <= 1'b0;
            rx_data_r <= 8'd0;
        end else begin
            // Clear rx_valid when DATA is read (read-clear; rx arrival wins if simultaneous)
            if (sel && !we && addr == 2'd0) rx_valid <= 1'b0;

            case (rx_state)
                RX_IDLE: begin
                    // Detect falling edge of synchronized rx = start bit
                    if (rx_s_prev && !rx_s) begin
                        rx_state <= RX_START;
                        rx_cnt   <= {1'b0, baud_div[15:1]};  // baud_div/2
                    end
                end

                RX_START: begin
                    if (rx_cnt == 16'd0) begin
                        if (!rx_s) begin   // still low — valid start bit
                            rx_state <= RX_DATA;
                            rx_bit   <= 3'd0;
                            rx_sr    <= 8'd0;
                            rx_cnt   <= baud_div;
                        end else begin     // glitch, abort
                            rx_state <= RX_IDLE;
                        end
                    end else begin
                        rx_cnt <= rx_cnt - 16'd1;
                    end
                end

                RX_DATA: begin
                    if (rx_cnt == 16'd0) begin
                        // Sample bit, shift into MSB (LSB-first protocol → bit0 arrives first → ends at [0])
                        rx_sr  <= {rx_s, rx_sr[7:1]};
                        rx_cnt <= baud_div;
                        if (rx_bit == 3'd7)
                            rx_state <= RX_STOP;
                        else
                            rx_bit <= rx_bit + 3'd1;
                    end else begin
                        rx_cnt <= rx_cnt - 16'd1;
                    end
                end

                RX_STOP: begin
                    // Wait one baud period for stop bit, then store
                    if (rx_cnt == 16'd0) begin
                        rx_data_r <= rx_sr;   // all 8 bits already shifted in
                        rx_valid  <= 1'b1;
                        rx_state  <= RX_IDLE;
                    end else begin
                        rx_cnt <= rx_cnt - 16'd1;
                    end
                end
            endcase
        end
    end

    // Registered rdata — matches 1-cycle BRAM latency expected by CPU
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) rdata <= 32'd0;
        else case (addr)
            2'd0:    rdata <= {24'd0, rx_data_r};
            2'd1:    rdata <= {30'd0, rx_valid, tx_idle};
            2'd2:    rdata <= {16'd0, baud_div};
            default: rdata <= 32'd0;
        endcase
    end

endmodule
