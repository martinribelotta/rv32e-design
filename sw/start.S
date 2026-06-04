// Minimal RV32I test program
// Exercises all instruction types

.section .text
.globl _start
_start:
    // Basic ALU
    li   x1, 10
    li   x2, 20
    add  x3, x1, x2       // x3 = 30
    sub  x4, x2, x1       // x4 = 10
    and  x5, x1, x2       // x5 = 0
    or   x6, x1, x2       // x6 = 30
    xor  x7, x1, x2       // x7 = 30
    sll  x8, x1, x2       // shift left
    srl  x9, x2, x1       // shift right logical
    sra  x10, x2, x1      // shift right arith
    slt  x11, x1, x2      // x11 = 1
    sltu x12, x1, x2      // x12 = 1

    // LUI / AUIPC
    lui  x13, 1            // x13 = 0x1000
    auipc x14, 0           // x14 = PC

    // Immediate ALU
    addi x15, x0, 42
    andi x16, x15, 0x0F
    ori  x17, x15, 0x100
    xori x18, x15, 0xFF
    slti x19, x15, 100
    sltiu x20, x15, 100
    slli x21, x15, 2
    srli x22, x15, 1
    srai x23, x15, 1

    // Store and load
    lui  x28, 0            // base addr = 0 in DMEM
    sw   x3,  0(x28)
    sw   x4,  4(x28)
    sh   x5,  8(x28)
    sb   x6,  10(x28)
    lw   x24, 0(x28)
    lh   x25, 8(x28)
    lb   x26, 10(x28)
    lhu  x27, 8(x28)
    lbu  x29, 10(x28)

    // Branches
    beq  x1, x1, eq_ok
    nop
eq_ok:
    bne  x1, x2, ne_ok
    nop
ne_ok:
    blt  x1, x2, lt_ok
    nop
lt_ok:
    bge  x2, x1, ge_ok
    nop
ge_ok:
    bltu x1, x2, ltu_ok
    nop
ltu_ok:
    bgeu x2, x1, geu_ok
    nop
geu_ok:

    // JAL / JALR
    jal  x30, jal_target
    nop
jal_target:
    jalr x0, x30, 0       // return to after jal

    // Infinite loop to end
done:
    j done
