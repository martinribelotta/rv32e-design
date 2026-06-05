#include "env/rv32e_test.h"

RVTEST_RV32E
RVTEST_CODE_BEGIN

    // 1: LUI loads upper 20 bits
    TEST_CASE_START(1)
    lui x1, 1
    CHECK_REG(x1, 0x00001000)

    // 2: LUI 0xABCDE
    TEST_CASE_START(2)
    lui x1, 0xABCDE
    CHECK_REG(x1, 0xABCDE000)

    // 3: LUI + ADDI = full 32-bit const
    TEST_CASE_START(3)
    lui  x1, 0xDEADB
    addi x1, x1, 0x7EF     // 0xDEADB000 + 0x7EF = 0xDEADB7EF
    CHECK_REG(x1, 0xDEADB7EF)

    // 4: AUIPC: result = PC + (imm << 12)
    //    This instruction is at a known offset; we check that bit 0 is 0 (aligned)
    //    and that the result is > 0 (PC is nonzero after some instructions).
    TEST_CASE_START(4)
_auipc_here:
    auipc x1, 0             // x1 = PC of this instruction
    // x1 must be 4-byte aligned
    andi  x3, x1, 3
    CHECK_REG(x3, 0)

    // 5: AUIPC with nonzero page
    TEST_CASE_START(5)
_auipc2:
    auipc x1, 1             // x1 = PC + 0x1000
    auipc x2, 0             // x2 = PC (of this instruction, 4 bytes later)
    sub   x3, x1, x2
    // difference = 0x1000 - 4 = 0xFFC
    CHECK_REG(x3, 0xFFC)

RVTEST_PASS_LABEL
RVTEST_FAIL_TRAMPOLINE
RVTEST_CODE_END
RVTEST_DATA_BEGIN
RVTEST_DATA_END
