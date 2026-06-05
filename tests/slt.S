#include "env/rv32e_test.h"

RVTEST_RV32E
RVTEST_CODE_BEGIN

    // 1: SLT true (signed)
    TEST_CASE_START(1)
    li  x1, -1
    li  x2, 0
    slt x3, x1, x2
    CHECK_REG(x3, 1)

    // 2: SLT false
    TEST_CASE_START(2)
    li  x1, 1
    li  x2, 0
    slt x3, x1, x2
    CHECK_REG(x3, 0)

    // 3: SLT equal → 0
    TEST_CASE_START(3)
    li  x1, 5
    slt x3, x1, x1
    CHECK_REG(x3, 0)

    // 4: SLTU: unsigned -1 (0xFFFFFFFF) > 0
    TEST_CASE_START(4)
    li  x1, 0
    li  x2, -1
    sltu x3, x1, x2
    CHECK_REG(x3, 1)

    // 5: SLTU false
    TEST_CASE_START(5)
    li  x1, -1
    li  x2, 0
    sltu x3, x1, x2
    CHECK_REG(x3, 0)

    // 6: SLTI signed
    TEST_CASE_START(6)
    li  x1, -5
    slti x3, x1, 0
    CHECK_REG(x3, 1)

    // 7: SLTIU unsigned
    TEST_CASE_START(7)
    li  x1, 1
    sltiu x3, x1, 10
    CHECK_REG(x3, 1)

RVTEST_PASS_LABEL
RVTEST_FAIL_TRAMPOLINE
RVTEST_CODE_END
RVTEST_DATA_BEGIN
RVTEST_DATA_END
