#include "env/rv32e_test.h"

RVTEST_RV32E
RVTEST_CODE_BEGIN

    // 1: SLL
    TEST_CASE_START(1)
    li  x1, 1
    li  x2, 4
    sll x3, x1, x2
    CHECK_REG(x3, 16)

    // 2: SLL by 0
    TEST_CASE_START(2)
    li  x1, 0xABCD
    li  x2, 0
    sll x3, x1, x2
    CHECK_REG(x3, 0xABCD)

    // 3: SRL (logical, fills with 0)
    TEST_CASE_START(3)
    li  x1, 0x80000000
    li  x2, 4
    srl x3, x1, x2
    CHECK_REG(x3, 0x08000000)

    // 4: SRA (arithmetic, fills with sign)
    TEST_CASE_START(4)
    li  x1, 0x80000000
    li  x2, 4
    sra x3, x1, x2
    CHECK_REG(x3, 0xF8000000)

    // 5: SRA positive no fill
    TEST_CASE_START(5)
    li  x1, 0x7FFFFFFF
    li  x2, 4
    sra x3, x1, x2
    CHECK_REG(x3, 0x07FFFFFF)

    // 6: SLLI
    TEST_CASE_START(6)
    li  x1, 1
    slli x3, x1, 10
    CHECK_REG(x3, 1024)

    // 7: SRLI
    TEST_CASE_START(7)
    li  x1, 0x80000000
    srli x3, x1, 1
    CHECK_REG(x3, 0x40000000)

    // 8: SRAI
    TEST_CASE_START(8)
    li  x1, 0x80000000
    srai x3, x1, 1
    CHECK_REG(x3, 0xC0000000)

    // 9: shift amount only lower 5 bits used
    TEST_CASE_START(9)
    li  x1, 1
    li  x2, 33          // 33 mod 32 = 1
    sll x3, x1, x2
    CHECK_REG(x3, 2)

RVTEST_PASS_LABEL
RVTEST_FAIL_TRAMPOLINE
RVTEST_CODE_END
RVTEST_DATA_BEGIN
RVTEST_DATA_END
