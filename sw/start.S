// Minimal RV32E test program — uses only x0-x15
// Exercises all instruction types

.section .text
.globl _start
_start:
    // --- ALU register ops ---
    li   x1, 10
    li   x2, 20
    add  x3, x1, x2        // x3  = 30   (0x1e)
    sub  x4, x2, x1        // x4  = 10   (0x0a)
    and  x5, x1, x2        // x5  = 0
    or   x6, x1, x2        // x6  = 30   (0x1e)
    xor  x7, x1, x2        // x7  = 30   (0x1e)
    sll  x8, x1, x2        // x8  = 10<<20 = 0x00a00000
    srl  x9, x2, x1        // x9  = 20>>10 = 0
    slt  x10, x1, x2       // x10 = 1
    sltu x11, x1, x2       // x11 = 1
    lui  x12, 1             // x12 = 0x00001000

    // --- Immediate ALU ---
    addi x1, x0, 42        // x1 = 42   (0x2a)
    andi x2, x1, 0x0F      // x2 = 10   (0x0a)
    ori  x3, x1, 0x100     // x3 = 298  (0x12a)
    xori x4, x1, 0xFF      // x4 = 213  (0xd5)
    slti x5, x1, 100       // x5 = 1
    sltiu x6, x1, 100      // x6 = 1
    slli x7, x1, 2         // x7 = 168  (0xa8)
    srli x8, x1, 1         // x8 = 21   (0x15)
    srai x9, x1, 1         // x9 = 21   (0x15)

    // --- Store / Load ---
    addi x13, x0, 0        // base = 0
    sw   x3,  0(x13)       // mem[0] = 0x12a
    sw   x4,  4(x13)       // mem[1] = 0xd5
    sh   x5,  8(x13)       // mem[2][15:0] = 1
    sb   x6, 10(x13)       // mem[2][23:16] = 1
    lw   x10, 0(x13)       // x10 = 0x12a
    lh   x11, 8(x13)       // x11 = 1
    lb   x12, 10(x13)      // x12 = 1

    // --- Branches ---
    li   x1, 10
    li   x2, 20
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

    // --- JAL / JALR ---
    jal  x14, jal_target
    nop
jal_target:
    jalr x0, x14, 0        // return to after jal

done:
    j done
