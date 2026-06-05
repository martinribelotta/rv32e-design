#include "env/rv32e_test.h"

RVTEST_RV32E
RVTEST_CODE_BEGIN

    li  x10, 0x00001000     // DMEM base

    // 1: SW / LW round-trip
    TEST_CASE_START(1)
    li  x1, 0xDEADBEEF
    sw  x1,  0(x10)
    lw  x3,  0(x10)
    CHECK_REG(x3, 0xDEADBEEF)

    // 2: SB / LBU — byte at offset 0
    TEST_CASE_START(2)
    li  x1, 0xAB
    sw  x0, 4(x10)          // clear word first
    sb  x1, 4(x10)
    lbu x3, 4(x10)
    CHECK_REG(x3, 0xAB)

    // 3: SB / LB sign extension (negative byte)
    TEST_CASE_START(3)
    li  x1, 0xFF
    sb  x1, 4(x10)
    lb  x3, 4(x10)
    CHECK_REG(x3, -1)

    // 4: SH / LHU — halfword at offset 8
    TEST_CASE_START(4)
    li  x1, 0x1234
    sw  x0, 8(x10)
    sh  x1, 8(x10)
    lhu x3, 8(x10)
    CHECK_REG(x3, 0x1234)

    // 5: SH / LH sign extension
    TEST_CASE_START(5)
    li  x1, 0x8000
    sh  x1, 8(x10)
    lh  x3, 8(x10)
    CHECK_REG(x3, 0xFFFF8000)

    // 6: LW with positive offset
    TEST_CASE_START(6)
    li  x1, 0x12345678
    sw  x1, 12(x10)
    lw  x3, 12(x10)
    CHECK_REG(x3, 0x12345678)

    // 7: byte at non-zero byte offset within word
    TEST_CASE_START(7)
    li  x1, 0xAABBCCDD
    sw  x1, 16(x10)
    lbu x3, 17(x10)         // byte 1 → 0xCC
    CHECK_REG(x3, 0xCC)

    // 8: halfword at offset 2 within word
    TEST_CASE_START(8)
    lhu x3, 18(x10)         // halfword at bytes [3:2] → 0xAABB
    CHECK_REG(x3, 0xAABB)

RVTEST_PASS_LABEL
RVTEST_FAIL_TRAMPOLINE
RVTEST_CODE_END
RVTEST_DATA_BEGIN
RVTEST_DATA_END
