#include "env/rv32e_test.h"

RVTEST_RV32E
RVTEST_CODE_BEGIN

    // 1: BEQ taken
    TEST_CASE_START(1)
    li  x1, 5
    li  x2, 5
    beq x1, x2, 1f
    j   _fail_jump
1:

    // 2: BEQ not taken
    TEST_CASE_START(2)
    li  x1, 5
    li  x2, 6
    beq x1, x2, _fail_jump

    // 3: BNE taken
    TEST_CASE_START(3)
    li  x1, 1
    li  x2, 2
    bne x1, x2, 3f
    j   _fail_jump
3:

    // 4: BNE not taken
    TEST_CASE_START(4)
    li  x1, 7
    li  x2, 7
    bne x1, x2, _fail_jump

    // 5: BLT taken (signed)
    TEST_CASE_START(5)
    li  x1, -1
    li  x2,  0
    blt x1, x2, 5f
    j   _fail_jump
5:

    // 6: BLT not taken
    TEST_CASE_START(6)
    li  x1, 1
    li  x2, 0
    blt x1, x2, _fail_jump

    // 7: BGE taken
    TEST_CASE_START(7)
    li  x1, 10
    li  x2, 10
    bge x1, x2, 7f
    j   _fail_jump
7:

    // 8: BGE taken (greater)
    TEST_CASE_START(8)
    li  x1, 11
    li  x2, 10
    bge x1, x2, 8f
    j   _fail_jump
8:

    // 9: BLTU taken (unsigned: 0 < 0xFFFFFFFF)
    TEST_CASE_START(9)
    li  x1, 0
    li  x2, -1              // 0xFFFFFFFF unsigned
    bltu x1, x2, 9f
    j   _fail_jump
9:

    // 10: BGEU taken
    TEST_CASE_START(10)
    li  x1, -1              // 0xFFFFFFFF
    li  x2,  0
    bgeu x1, x2, 10f
    j   _fail_jump
10:

RVTEST_PASS_LABEL
RVTEST_FAIL_TRAMPOLINE
RVTEST_CODE_END
RVTEST_DATA_BEGIN
RVTEST_DATA_END
