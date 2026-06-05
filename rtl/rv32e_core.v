`include "rv32e_pkg.v"

// RV32I 3-stage pipeline: IF | ID/EX | MEM/WB
// Stage 1: IF  - fetch instruction from IMEM
// Stage 2: ID/EX - decode + register read + ALU execute
// Stage 3: MEM/WB - memory access + writeback
module rv32e_core #(
    parameter IMEM_DEPTH = 1024,  // words; must match bram_dp DEPTH
    parameter DMEM_DEPTH = 1024
) (
    input  wire        clk,
    input  wire        rst_n,
    // Instruction memory interface
    output wire [$clog2(IMEM_DEPTH)-1:0] imem_addr,
    input  wire [31:0] imem_rdata,
    // Data memory interface
    output wire [$clog2(DMEM_DEPTH)-1:0] dmem_addr,
    output wire [31:0] dmem_wdata,
    output wire [3:0]  dmem_we,
    input  wire [31:0] dmem_rdata
);

    // =========================================================
    // PC and IF stage
    // =========================================================
    reg [31:0] pc;
    reg [31:0] fetch_pc;    // PC of the instruction currently in IMEM (one cycle behind pc)
    reg [31:0] if_id_pc;
    reg [31:0] if_id_instr;

    wire        take_branch;
    wire [31:0] branch_target;
    wire        stall;  // load-use hazard

    wire [31:0] pc_next = take_branch ? branch_target : pc + 32'd4;

    // During a stall, pc is frozen at the instruction AFTER the stalled pair.
    // We need the BRAM to re-fetch the instruction that follows the load (pc-4),
    // so we back the address up by one word while stall is asserted.
    assign imem_addr = stall ? pc[$clog2(IMEM_DEPTH)+1:2] - 1
                             : pc[$clog2(IMEM_DEPTH)+1:2];

    // Synchronous IMEM: address presented at cycle N → data available at cycle N+1.
    // fetch_pc tracks the address given to IMEM last cycle, so if_id_pc = correct instr addr.
    // flush_pending: take_branch inserts one NOP (bubble 1); flush_pending inserts
    // a second NOP to discard the stale imem_rdata that arrives one cycle after branch.
    reg flush_pending;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc            <= 32'd0;
            fetch_pc      <= 32'd0;
            if_id_pc      <= 32'd0;
            if_id_instr   <= 32'h00000013;
            flush_pending <= 1'b0;
        end else if (!stall) begin
            pc            <= pc_next;
            fetch_pc      <= pc;           // fetch_pc = address presented to IMEM this cycle
            flush_pending <= take_branch;
            if_id_pc      <= (take_branch || flush_pending) ? 32'd0        : fetch_pc;
            if_id_instr   <= (take_branch || flush_pending) ? 32'h00000013 : imem_rdata;
        end
    end

    // =========================================================
    // ID/EX stage
    // =========================================================
    wire [6:0]  dec_opcode;
    wire [3:0]  dec_rs1, dec_rs2, dec_rd;
    wire [2:0]  dec_funct3;
    wire [6:0]  dec_funct7;
    wire [31:0] dec_imm;
    wire [3:0]  dec_alu_op;
    wire        dec_alu_src;
    wire        dec_mem_read, dec_mem_write;
    wire        dec_reg_write;
    wire        dec_branch, dec_jal, dec_jalr;
    wire        dec_lui, dec_auipc;

    decoder dec_inst (
        .instr     (if_id_instr),
        .opcode    (dec_opcode),
        .rs1       (dec_rs1),
        .rs2       (dec_rs2),
        .rd        (dec_rd),
        .funct3    (dec_funct3),
        .funct7    (dec_funct7),
        .imm       (dec_imm),
        .alu_op    (dec_alu_op),
        .alu_src   (dec_alu_src),
        .mem_read  (dec_mem_read),
        .mem_write (dec_mem_write),
        .reg_write (dec_reg_write),
        .branch    (dec_branch),
        .jal       (dec_jal),
        .jalr      (dec_jalr),
        .lui       (dec_lui),
        .auipc     (dec_auipc)
    );

    // EX/MEM pipeline register
    reg [31:0] ex_mem_alu_result;
    reg [3:0]  ex_mem_rd;
    reg [2:0]  ex_mem_funct3;
    reg        ex_mem_mem_read;
    reg        ex_mem_reg_write;

    // Load-use hazard: next instr reads a reg written by current load
    wire load_use_hazard = ex_mem_mem_read &&
                           ((dec_rs1 == ex_mem_rd) || (dec_rs2 == ex_mem_rd)) &&
                           (ex_mem_rd != 4'd0);
    assign stall = load_use_hazard;

    // Register file
    wire [31:0] rf_rdata1, rf_rdata2;
    wire        wb_reg_write;
    wire [3:0]  wb_rd;
    wire [31:0] wb_wdata;

    // BRAM regfile needs the read address ONE cycle early (during IF stage).
    // Extract rs1/rs2 from imem_rdata (the instruction arriving from IMEM this cycle,
    // which will become if_id_instr next cycle).
    // During flush: feed x0 so the BRAM outputs a harmless zero.
    // During stall: re-present the frozen dec_rs1/dec_rs2 so BRAM re-reads the same regs.
    wire [3:0] if_rs1 = (take_branch || flush_pending) ? 4'd0 : imem_rdata[18:15];
    wire [3:0] if_rs2 = (take_branch || flush_pending) ? 4'd0 : imem_rdata[23:20];
    wire [3:0] rf_rs1 = stall ? dec_rs1 : if_rs1;
    wire [3:0] rf_rs2 = stall ? dec_rs2 : if_rs2;

    regfile rf (
        .clk    (clk),
        .we     (wb_reg_write),
        .rs1    (rf_rs1),
        .rs2    (rf_rs2),
        .rd     (wb_rd),
        .wdata  (wb_wdata),
        .rdata1 (rf_rdata1),
        .rdata2 (rf_rdata2)
    );

    // Forwarding
    // EX/MEM forwarding (result of previous ALU op)
    wire fwd_ex_rs1 = ex_mem_reg_write && (ex_mem_rd != 4'd0) && (ex_mem_rd == dec_rs1);
    wire fwd_ex_rs2 = ex_mem_reg_write && (ex_mem_rd != 4'd0) && (ex_mem_rd == dec_rs2);
    // MEM/WB forwarding
    wire fwd_wb_rs1 = wb_reg_write && (wb_rd != 4'd0) && (wb_rd == dec_rs1) && !fwd_ex_rs1;
    wire fwd_wb_rs2 = wb_reg_write && (wb_rd != 4'd0) && (wb_rd == dec_rs2) && !fwd_ex_rs2;

    wire [31:0] op_a = fwd_ex_rs1 ? ex_mem_alu_result :
                       fwd_wb_rs1 ? wb_wdata           : rf_rdata1;
    wire [31:0] op_b_reg = fwd_ex_rs2 ? ex_mem_alu_result :
                           fwd_wb_rs2 ? wb_wdata           : rf_rdata2;

    wire [31:0] alu_a = dec_auipc ? if_id_pc : op_a;
    wire [31:0] alu_b = dec_alu_src ? dec_imm : op_b_reg;

    wire [31:0] alu_result;
    alu alu_inst (
        .op     (dec_alu_op),
        .a      (alu_a),
        .b      (alu_b),
        .result (alu_result)
    );

    // Branch evaluation
    wire branch_taken;
    branch_unit bu (
        .funct3  (dec_funct3),
        .a       (op_a),
        .b       (op_b_reg),
        .taken   (branch_taken)
    );

    wire do_branch = dec_branch && branch_taken;
    // Gate on !stall: a branch/jump following a load uses forwarded alu_result
    // (load address) not the loaded data. Stall one cycle to get the real value.
    assign take_branch = (do_branch || dec_jal || dec_jalr) && !stall;
    assign branch_target = dec_jal  ? (if_id_pc + dec_imm) :
                           dec_jalr ? ((op_a + dec_imm) & ~32'd1) :
                                      (if_id_pc + dec_imm);

    // JAL/JALR write PC+4 to rd
    wire [31:0] id_ex_result = (dec_jal || dec_jalr) ? (if_id_pc + 32'd4) : alu_result;

    // No take_branch flush on the EX/MEM register.
    //
    // Removing it serves two purposes:
    //   1. Fixes a bug: JAL/JALR need their result (PC+4 → rd) to reach MEM/WB.
    //      Flushing ex_mem_reg_write would silently discard the link register write.
    //   2. Eliminates the pattern where alu_result/rs2_data/funct3/rd had
    //      CEN = take_branch | !stall, which Yosys kept as a separate CE signal
    //      with fanout ~75, triggering nextpnr's global-CE promotion and
    //      routing that signal through the critical path.
    //
    // Safety: after take_branch, if_id_instr is overwritten with NOP
    // (ADDI x0,x0,0).  The NOP decodes to dec_jal=0, dec_branch=0,
    // dec_mem_read=0, dec_mem_write=0, dec_rd=x0 — so the bubble that enters
    // EX/MEM the next cycle is harmless (writes to x0, no memory access).
    // All assignments fully muxed → CEN=1 for every bit.
    // stall inserts a NOP bubble by zeroing control signals and clearing rd;
    // data registers hold their value on stall (don't care, guarded by control).
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ex_mem_alu_result <= 32'd0;
            ex_mem_rd         <= 4'd0;
            ex_mem_funct3     <= 3'd0;
            ex_mem_mem_read   <= 1'b0;
            ex_mem_reg_write  <= 1'b0;
        end else begin
            ex_mem_alu_result <= stall ? ex_mem_alu_result : id_ex_result;
            ex_mem_rd         <= stall ? 4'd0              : dec_rd;
            ex_mem_funct3     <= stall ? ex_mem_funct3     : dec_funct3;
            ex_mem_mem_read   <= stall ? 1'b0              : dec_mem_read;
            ex_mem_reg_write  <= stall ? 1'b0              : dec_reg_write;
        end
    end

    // =========================================================
    // ID/EX → DMEM interface (address presented one cycle early so the
    // BRAM's registered output is valid in the MEM/WB stage)
    // =========================================================

    // Word address driven from combinational ALU result (ID/EX stage)
    assign dmem_addr = alu_result[$clog2(DMEM_DEPTH)+1:2];

    // Store data normalised to byte-lane 0
    wire [31:0] idex_store_wdata =
        (dec_funct3[1:0] == 2'b00) ? {24'h0, op_b_reg[7:0]}  :  // SB
        (dec_funct3[1:0] == 2'b01) ? {16'h0, op_b_reg[15:0]} :  // SH
                                      op_b_reg;                   // SW

    // Shift to correct byte lane
    wire [31:0] idex_wdata_shifted =
        (alu_result[1:0] == 2'b01) ? {idex_store_wdata[23:0],  8'h0} :
        (alu_result[1:0] == 2'b10) ? {idex_store_wdata[15:0], 16'h0} :
        (alu_result[1:0] == 2'b11) ? {idex_store_wdata[ 7:0], 24'h0} :
                                      idex_store_wdata;
    assign dmem_wdata = idex_wdata_shifted;

    // Byte enables from combinational decode
    wire [3:0] idex_store_be =
        (dec_funct3[1:0] == 2'b00) ? (4'b0001 << alu_result[1:0])       :  // SB
        (dec_funct3[1:0] == 2'b01) ? (alu_result[1] ? 4'b1100 : 4'b0011) : // SH
                                      4'b1111;                               // SW
    assign dmem_we = (dec_mem_write && !stall) ? idex_store_be : 4'b0000;

    // =========================================================
    // MEM/WB stage — dmem_rdata is now valid (registered BRAM output)
    // byte offset comes from ex_mem_alu_result which was registered at
    // the same clock edge the BRAM address was presented
    // =========================================================

    wire [7:0]  load_byte =
        (ex_mem_alu_result[1:0] == 2'b00) ? dmem_rdata[ 7: 0] :
        (ex_mem_alu_result[1:0] == 2'b01) ? dmem_rdata[15: 8] :
        (ex_mem_alu_result[1:0] == 2'b10) ? dmem_rdata[23:16] :
                                            dmem_rdata[31:24];

    wire [15:0] load_half = ex_mem_alu_result[1] ? dmem_rdata[31:16] : dmem_rdata[15:0];

    wire [31:0] load_data =
        (ex_mem_funct3[2:0] == 3'b000) ? {{24{load_byte[7]}},  load_byte} :  // LB
        (ex_mem_funct3[2:0] == 3'b001) ? {{16{load_half[15]}}, load_half} :  // LH
        (ex_mem_funct3[2:0] == 3'b010) ? dmem_rdata :                         // LW
        (ex_mem_funct3[2:0] == 3'b100) ? {24'h0, load_byte} :                // LBU
        (ex_mem_funct3[2:0] == 3'b101) ? {16'h0, load_half} :                // LHU
                                         dmem_rdata;

    // WB mux
    assign wb_wdata     = ex_mem_mem_read ? load_data : ex_mem_alu_result;
    assign wb_reg_write = ex_mem_reg_write;
    assign wb_rd        = ex_mem_rd;

endmodule

// Branch condition unit
module branch_unit (
    input  wire [2:0]  funct3,
    input  wire [31:0] a,
    input  wire [31:0] b,
    output reg         taken
);
    always @(*) begin
        case (funct3)
            3'b000: taken = (a == b);                         // BEQ
            3'b001: taken = (a != b);                         // BNE
            3'b100: taken = ($signed(a) < $signed(b));        // BLT
            3'b101: taken = ($signed(a) >= $signed(b));       // BGE
            3'b110: taken = (a < b);                          // BLTU
            3'b111: taken = (a >= b);                         // BGEU
            default: taken = 1'b0;
        endcase
    end
endmodule
