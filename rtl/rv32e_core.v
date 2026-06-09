`include "rv32e_pkg.v"

// RV32E 3-stage pipeline: IF | ID/EX | MEM/WB
// Stage 1: IF  - fetch instruction from IMEM
// Stage 2: ID/EX - decode + register read + ALU execute + CSR semantics
// Stage 3: MEM/WB - memory access + writeback + CSR commit
module rv32e_core #(
    parameter IMEM_DEPTH = 1024,  // words; must match bram_dp DEPTH
    parameter DMEM_DEPTH = 1024
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        irq,
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
    wire        take_trap;
    wire        take_mret;
    wire        take_control_flow;
    wire        stall;
    wire [31:0] branch_target;

    reg [31:0] csr_mstatus;
    reg [31:0] csr_mie;
    reg [31:0] csr_mtvec;
    reg [31:0] csr_mepc;
    reg [31:0] csr_mcause;
    reg [63:0] csr_mcycle;
    reg        irq_sync0, irq_sync1;

    wire [31:0] pc_next = take_mret ? csr_mepc :
                           take_trap ? csr_mtvec :
                           take_branch ? branch_target :
                           pc + 32'd4;

    // During a stall, pc is frozen at the instruction AFTER the stalled pair.
    // We need the BRAM to re-fetch the instruction that follows the load (pc-4),
    // so we back the address up by one word while stall is asserted.
    assign imem_addr = stall ? pc[$clog2(IMEM_DEPTH)+1:2] - 1
                             : pc[$clog2(IMEM_DEPTH)+1:2];

    // Synchronous IMEM: address presented at cycle N → data available at cycle N+1.
    // fetch_pc tracks the address given to IMEM last cycle, so if_id_pc = correct instr addr.
    // flush_pending: take_branch/take_trap/take_mret inserts one NOP; flush_pending inserts
    // a second NOP to discard stale imem_rdata that arrives one cycle after the control transfer.
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
            fetch_pc      <= pc;
            flush_pending <= take_control_flow;
            if_id_pc      <= (take_control_flow || flush_pending) ? 32'd0 : fetch_pc;
            if_id_instr   <= (take_control_flow || flush_pending) ? 32'h00000013 : imem_rdata;
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
    wire        dec_csr, dec_csr_imm;
    wire [2:0]  dec_csr_cmd;
    wire [11:0] dec_csr_addr;
    wire        dec_ecall, dec_ebreak, dec_mret, dec_fence;

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
        .auipc     (dec_auipc),
        .csr       (dec_csr),
        .csr_cmd   (dec_csr_cmd),
        .csr_imm   (dec_csr_imm),
        .csr_addr  (dec_csr_addr),
        .ecall     (dec_ecall),
        .ebreak    (dec_ebreak),
        .mret      (dec_mret),
        .fence     (dec_fence)
    );

    // CSR pipeline state in EX/MEM
    reg        ex_mem_csr_we;
    reg [11:0] ex_mem_csr_addr;
    reg [31:0] ex_mem_csr_wdata;

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
    wire [3:0] if_rs1 = (take_control_flow || flush_pending) ? 4'd0 : imem_rdata[18:15];
    wire [3:0] if_rs2 = (take_control_flow || flush_pending) ? 4'd0 : imem_rdata[23:20];
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

    // CSR sources
    wire [31:0] csr_src_data = dec_csr_imm ? {27'd0, dec_rs1} : op_a;
    wire [31:0] csr_old_value;
    wire [31:0] csr_new_value =
        (dec_csr_cmd == `CSR_RW  || dec_csr_cmd == `CSR_RWZ) ? csr_src_data :
        (dec_csr_cmd == `CSR_RS  || dec_csr_cmd == `CSR_RSZI) ? (csr_old_value | csr_src_data) :
        (dec_csr_cmd == `CSR_RC  || dec_csr_cmd == `CSR_RCZI) ? (csr_old_value & ~csr_src_data) :
                                                                 32'd0;
    wire csr_src_zero = dec_csr_imm ? (dec_rs1 == 4'd0) : (csr_src_data == 32'd0);
    wire csr_write_enable = dec_csr && (
            (dec_csr_cmd == `CSR_RW)  ||
            (dec_csr_cmd == `CSR_RWZ) ||
            ((dec_csr_cmd == `CSR_RS)  && !csr_src_zero) ||
            ((dec_csr_cmd == `CSR_RC)  && !csr_src_zero) ||
            ((dec_csr_cmd == `CSR_RSZI) && (dec_rs1 != 4'd0)) ||
            ((dec_csr_cmd == `CSR_RCZI) && (dec_rs1 != 4'd0))
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
    assign take_branch = (do_branch || dec_jal || dec_jalr) && !stall;
    assign branch_target = dec_jal  ? (if_id_pc + dec_imm) :
                           dec_jalr ? ((op_a + dec_imm) & ~32'd1) :
                                      (if_id_pc + dec_imm);

    // Interrupt and exception handling
    wire        irq_pending;
    wire [31:0] trap_cause;
    assign irq_pending = irq_sync1 && csr_mstatus[3] && csr_mie[11];
    assign take_trap = (dec_ecall || dec_ebreak || irq_pending) && !stall && !dec_mret;
    assign take_mret = dec_mret && !stall;
    assign take_control_flow = take_branch || take_trap || take_mret;

    assign trap_cause = dec_ebreak ? 32'd3 :
                        dec_ecall ? 32'd11 :
                        32'h8000000B;

    // JAL/JALR write PC+4 to rd
    wire [31:0] id_ex_result = dec_csr ? csr_old_value :
                               (dec_jal || dec_jalr) ? (if_id_pc + 32'd4) :
                                                         alu_result;

    // No take_branch or take_control_flow flush on the EX/MEM register.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ex_mem_alu_result <= 32'd0;
            ex_mem_rd         <= 4'd0;
            ex_mem_funct3     <= 3'd0;
            ex_mem_mem_read   <= 1'b0;
            ex_mem_reg_write  <= 1'b0;
            ex_mem_csr_we     <= 1'b0;
            ex_mem_csr_addr   <= 12'd0;
            ex_mem_csr_wdata  <= 32'd0;
        end else begin
            ex_mem_alu_result <= stall ? ex_mem_alu_result : id_ex_result;
            ex_mem_rd         <= stall ? 4'd0              : dec_rd;
            ex_mem_funct3     <= stall ? ex_mem_funct3     : dec_funct3;
            ex_mem_mem_read   <= stall ? 1'b0              : dec_mem_read;
            ex_mem_reg_write  <= stall ? 1'b0              : dec_reg_write;
            ex_mem_csr_we     <= stall ? ex_mem_csr_we     : csr_write_enable;
            ex_mem_csr_addr   <= stall ? ex_mem_csr_addr   : dec_csr_addr;
            ex_mem_csr_wdata  <= stall ? ex_mem_csr_wdata  : csr_new_value;
        end
    end

    // =========================================================
    // ID/EX → DMEM interface (address presented one cycle early so the
    // BRAM's registered output is valid in the MEM/WB stage)
    // =========================================================

    assign dmem_addr = alu_result[$clog2(DMEM_DEPTH)+1:2];

    wire [31:0] idex_store_wdata =
        (dec_funct3[1:0] == 2'b00) ? {24'h0, op_b_reg[7:0]}  :  // SB
        (dec_funct3[1:0] == 2'b01) ? {16'h0, op_b_reg[15:0]} :  // SH
                                      op_b_reg;                   // SW

    wire [31:0] idex_wdata_shifted =
        (alu_result[1:0] == 2'b01) ? {idex_store_wdata[23:0],  8'h0} :
        (alu_result[1:0] == 2'b10) ? {idex_store_wdata[15:0], 16'h0} :
        (alu_result[1:0] == 2'b11) ? {idex_store_wdata[ 7:0], 24'h0} :
                                      idex_store_wdata;
    assign dmem_wdata = idex_wdata_shifted;

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

    // CSR registers
    wire [31:0] csr_read_data;
    assign csr_read_data =
        (dec_csr_addr == `CSR_MSTATUS) ? csr_mstatus :
        (dec_csr_addr == `CSR_MIE)     ? csr_mie :
        (dec_csr_addr == `CSR_MTVEC)   ? csr_mtvec :
        (dec_csr_addr == `CSR_MEPC)    ? csr_mepc :
        (dec_csr_addr == `CSR_MCAUSE)  ? csr_mcause :
        (dec_csr_addr == `CSR_MCYCLE)  ? csr_mcycle[31:0] :
        (dec_csr_addr == `CSR_MCYCLEH) ? csr_mcycle[63:32] :
                                        32'd0;

    assign csr_old_value = csr_read_data;

    // IRQ synchronizer
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            irq_sync0 <= 1'b0;
            irq_sync1 <= 1'b0;
        end else begin
            irq_sync0 <= irq;
            irq_sync1 <= irq_sync0;
        end
    end

    // Commit CSR writes, timer and trap state
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            csr_mstatus <= 32'd0;
            csr_mie     <= 32'd0;
            csr_mtvec   <= 32'd0;
            csr_mepc    <= 32'd0;
            csr_mcause  <= 32'd0;
            csr_mcycle  <= 64'd0;
        end else begin
            csr_mcycle <= csr_mcycle + 64'd1;

            if (ex_mem_csr_we) begin
                case (ex_mem_csr_addr)
                    `CSR_MSTATUS: csr_mstatus <= ex_mem_csr_wdata;
                    `CSR_MIE:     csr_mie     <= ex_mem_csr_wdata;
                    `CSR_MTVEC:   csr_mtvec   <= ex_mem_csr_wdata;
                    `CSR_MEPC:    csr_mepc    <= ex_mem_csr_wdata;
                    `CSR_MCAUSE:  csr_mcause  <= ex_mem_csr_wdata;
                    `CSR_MCYCLE:  csr_mcycle[31:0]  <= ex_mem_csr_wdata;
                    `CSR_MCYCLEH: csr_mcycle[63:32] <= ex_mem_csr_wdata;
                    default: ;
                endcase
            end

            if (take_trap) begin
                csr_mstatus[3] <= 1'b0;
                csr_mepc       <= if_id_pc;
                csr_mcause     <= trap_cause;
            end else if (take_mret) begin
                csr_mstatus[3] <= 1'b1;
            end
        end
    end

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
