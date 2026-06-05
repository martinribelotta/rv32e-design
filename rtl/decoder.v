`include "rv32i_pkg.v"

// Combinational decode stage
module decoder (
    input  wire [31:0] instr,
    output reg  [6:0]  opcode,
    output reg  [3:0]  rs1,
    output reg  [3:0]  rs2,
    output reg  [3:0]  rd,
    output reg  [2:0]  funct3,
    output reg  [6:0]  funct7,
    output reg  [31:0] imm,
    output reg  [3:0]  alu_op,
    output reg         alu_src,   // 0=reg, 1=imm
    output reg         mem_read,
    output reg         mem_write,
    output reg         reg_write,
    output reg         branch,
    output reg         jal,
    output reg         jalr,
    output reg         lui,
    output reg         auipc
);
    wire [6:0] op = instr[6:0];

    // Immediate decode
    wire [31:0] imm_i = {{21{instr[31]}}, instr[30:20]};
    wire [31:0] imm_s = {{21{instr[31]}}, instr[30:25], instr[11:7]};
    wire [31:0] imm_b = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
    wire [31:0] imm_u = {instr[31:12], 12'd0};
    wire [31:0] imm_j = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};

    always @(*) begin
        opcode    = op;
        rs1       = instr[18:15];
        rs2       = instr[23:20];
        rd        = instr[10:7];
        funct3    = instr[14:12];
        funct7    = instr[31:25];
        imm       = 32'd0;
        alu_op    = `ALU_ADD;
        alu_src   = 1'b0;
        mem_read  = 1'b0;
        mem_write = 1'b0;
        reg_write = 1'b0;
        branch    = 1'b0;
        jal       = 1'b0;
        jalr      = 1'b0;
        lui       = 1'b0;
        auipc     = 1'b0;

        case (op)
            `OP_LUI: begin
                imm = imm_u; reg_write = 1'b1; lui = 1'b1;
                alu_op = `ALU_PASS; alu_src = 1'b1;
            end
            `OP_AUIPC: begin
                imm = imm_u; reg_write = 1'b1; auipc = 1'b1;
                alu_op = `ALU_ADD; alu_src = 1'b1;
            end
            `OP_JAL: begin
                imm = imm_j; reg_write = 1'b1; jal = 1'b1;
            end
            `OP_JALR: begin
                imm = imm_i; reg_write = 1'b1; jalr = 1'b1;
                alu_op = `ALU_ADD; alu_src = 1'b1;
            end
            `OP_BRANCH: begin
                imm = imm_b; branch = 1'b1;
                case (instr[14:12])
                    3'b000: alu_op = `ALU_SUB;
                    3'b001: alu_op = `ALU_SUB;
                    3'b100: alu_op = `ALU_SLT;
                    3'b101: alu_op = `ALU_SLT;
                    3'b110: alu_op = `ALU_SLTU;
                    3'b111: alu_op = `ALU_SLTU;
                    default: alu_op = `ALU_SUB;
                endcase
            end
            `OP_LOAD: begin
                imm = imm_i; mem_read = 1'b1; reg_write = 1'b1;
                alu_op = `ALU_ADD; alu_src = 1'b1;
            end
            `OP_STORE: begin
                imm = imm_s; mem_write = 1'b1;
                alu_op = `ALU_ADD; alu_src = 1'b1;
            end
            `OP_IMM: begin
                imm = imm_i; reg_write = 1'b1; alu_src = 1'b1;
                case (instr[14:12])
                    3'b000: alu_op = `ALU_ADD;
                    3'b001: alu_op = `ALU_SLL;
                    3'b010: alu_op = `ALU_SLT;
                    3'b011: alu_op = `ALU_SLTU;
                    3'b100: alu_op = `ALU_XOR;
                    3'b101: alu_op = (instr[30]) ? `ALU_SRA : `ALU_SRL;
                    3'b110: alu_op = `ALU_OR;
                    3'b111: alu_op = `ALU_AND;
                    default: alu_op = `ALU_ADD;
                endcase
            end
            `OP_REG: begin
                reg_write = 1'b1;
                case ({instr[30], instr[14:12]})
                    4'b0000: alu_op = `ALU_ADD;
                    4'b1000: alu_op = `ALU_SUB;
                    4'b0001: alu_op = `ALU_SLL;
                    4'b0010: alu_op = `ALU_SLT;
                    4'b0011: alu_op = `ALU_SLTU;
                    4'b0100: alu_op = `ALU_XOR;
                    4'b0101: alu_op = `ALU_SRL;
                    4'b1101: alu_op = `ALU_SRA;
                    4'b0110: alu_op = `ALU_OR;
                    4'b0111: alu_op = `ALU_AND;
                    default: alu_op = `ALU_ADD;
                endcase
            end
            default: begin end
        endcase
    end
endmodule
