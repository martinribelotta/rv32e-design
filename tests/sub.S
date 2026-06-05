#include "env/rv32e_test.h"

RVTEST_RV32E
RVTEST_CODE_BEGIN

    // 1: basic subtraction
    TEST_CASE_START(1)
    li  x1, 20
    li  x2, 7
    sub x3, x1, x2
    CHECK_REG(x3, 13)

    // 2: result negative
    TEST_CASE_START(2)
    li  x1, 3
    li  x2, 10
    sub x3, x1, x2
    CHECK_REG(x3, -7)

    // 3: SUB same value → 0
    TEST_CASE_START(3)
    li  x1, 0xdeadbeef
    sub x3, x1, x1
    CHECK_REG(x3, 0)

    // 4: SUB underflow wraps
    TEST_CASE_START(4)
    li  x1, 0x80000000
    li  x2, 1
    sub x3, x1, x2
    CHECK_REG(x3, 0x7fffffff)

RVTEST_PASS_LABEL
RVTEST_FAIL_TRAMPOLINE
RVTEST_CODE_END
RVTEST_DATA_BEGIN
RVTEST_DATA_END
