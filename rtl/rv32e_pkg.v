// RV32I opcodes and constants
`ifndef RV32I_PKG_V
`define RV32I_PKG_V

// Opcodes
`define OP_LUI    7'b0110111
`define OP_AUIPC  7'b0010111
`define OP_JAL    7'b1101111
`define OP_JALR   7'b1100111
`define OP_BRANCH 7'b1100011
`define OP_LOAD   7'b0000011
`define OP_STORE  7'b0100011
`define OP_IMM    7'b0010011
`define OP_REG    7'b0110011
`define OP_FENCE  7'b0001111
`define OP_SYSTEM 7'b1110011

// ALU operations
`define ALU_ADD  4'd0
`define ALU_SUB  4'd1
`define ALU_SLL  4'd2
`define ALU_SLT  4'd3
`define ALU_SLTU 4'd4
`define ALU_XOR  4'd5
`define ALU_SRL  4'd6
`define ALU_SRA  4'd7
`define ALU_OR   4'd8
`define ALU_AND  4'd9
`define ALU_PASS 4'd10

// CSR addresses
`define CSR_MSTATUS 12'h300
`define CSR_MIE     12'h304
`define CSR_MTVEC   12'h305
`define CSR_MEPC    12'h341
`define CSR_MCAUSE  12'h342
`define CSR_MIP     12'h344
`define CSR_MCYCLE  12'hB00
`define CSR_MCYCLEH 12'hB80

// CSR command types
`define CSR_RW   3'd1
`define CSR_RS   3'd2
`define CSR_RC   3'd3
`define CSR_RWZ  3'd5
`define CSR_RSZI 3'd6
`define CSR_RCZI 3'd7

// Branch types
`define BR_EQ  3'd0
`define BR_NE  3'd1
`define BR_LT  3'd4
`define BR_GE  3'd5
`define BR_LTU 3'd6
`define BR_GEU 3'd7

`endif
