#include "env/rv32e_test.h"

RVTEST_RV32E
RVTEST_CODE_BEGIN

    // 1: basic ADDI
    TEST_CASE_START(1)
    li  x1, 100
    addi x3, x1, 23
    CHECK_REG(x3, 123)

    // 2: ADDI negative immediate
    TEST_CASE_START(2)
    li  x1, 100
    addi x3, x1, -50
    CHECK_REG(x3, 50)

    // 3: ADDI max positive immediate (2047)
    TEST_CASE_START(3)
    li  x1, 0
    addi x3, x1, 2047
    CHECK_REG(x3, 2047)

    // 4: ADDI min negative immediate (-2048)
    TEST_CASE_START(4)
    li  x1, 0
    addi x3, x1, -2048
    CHECK_REG(x3, -2048)

    // 5: LI pseudo (ADDI x, x0, imm)
    TEST_CASE_START(5)
    li  x3, 42
    CHECK_REG(x3, 42)

    // 6: MV pseudo (ADDI x, rs, 0)
    TEST_CASE_START(6)
    li  x1, 77
    mv  x3, x1
    CHECK_REG(x3, 77)

RVTEST_PASS_LABEL
RVTEST_FAIL_TRAMPOLINE
RVTEST_CODE_END
RVTEST_DATA_BEGIN
RVTEST_DATA_END
