#include "env/rv32e_test.h"

RVTEST_RV32E
RVTEST_CODE_BEGIN

    li  x1, 0xFF00FF00
    li  x2, 0x0F0F0F0F

    // 1: AND
    TEST_CASE_START(1)
    and x3, x1, x2
    CHECK_REG(x3, 0x0F000F00)

    // 2: OR
    TEST_CASE_START(2)
    or  x3, x1, x2
    CHECK_REG(x3, 0xFF0FFF0F)

    // 3: XOR
    TEST_CASE_START(3)
    xor x3, x1, x2
    CHECK_REG(x3, 0xF00FF00F)

    // 4: ANDI
    TEST_CASE_START(4)
    li  x1, 0xFF
    andi x3, x1, 0x0F
    CHECK_REG(x3, 0x0F)

    // 5: ORI
    TEST_CASE_START(5)
    li  x1, 0xF0
    ori  x3, x1, 0x0F
    CHECK_REG(x3, 0xFF)

    // 6: XORI
    TEST_CASE_START(6)
    li  x1, 0xFF
    xori x3, x1, 0x0F
    CHECK_REG(x3, 0xF0)

    // 7: XORI with -1 acts as NOT
    TEST_CASE_START(7)
    li  x1, 0xAAAAAAAA
    xori x3, x1, -1
    CHECK_REG(x3, 0x55555555)

RVTEST_PASS_LABEL
RVTEST_FAIL_TRAMPOLINE
RVTEST_CODE_END
RVTEST_DATA_BEGIN
RVTEST_DATA_END
