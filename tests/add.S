#include "env/rv32e_test.h"

RVTEST_RV32E
RVTEST_CODE_BEGIN

    // 1: ADD positive
    TEST_CASE_START(1)
    li  x1, 10
    li  x2, 20
    add x3, x1, x2
    CHECK_REG(x3, 30)

    // 2: ADD negative result
    TEST_CASE_START(2)
    li  x1, 5
    li  x2, -10
    add x3, x1, x2
    CHECK_REG(x3, -5)

    // 3: ADD overflow wraps
    TEST_CASE_START(3)
    li  x1, 0x7fffffff
    li  x2, 1
    add x3, x1, x2
    CHECK_REG(x3, 0x80000000)

    // 4: ADD with zero
    TEST_CASE_START(4)
    li  x1, 42
    add x3, x1, x0
    CHECK_REG(x3, 42)

    // 5: ADD writing to x0 stays zero
    TEST_CASE_START(5)
    li  x1, 99
    li  x2, 1
    add x0, x1, x2
    CHECK_REG(x0, 0)

RVTEST_PASS_LABEL
RVTEST_FAIL_TRAMPOLINE
RVTEST_CODE_END
RVTEST_DATA_BEGIN
RVTEST_DATA_END
