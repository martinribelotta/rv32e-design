//
// Pipeline hazard tests: load-use, ALU forwarding, branch after load
//
#include "env/rv32e_test.h"

RVTEST_RV32E
RVTEST_CODE_BEGIN

    li  x10, 0x00001000     // DMEM base

    // 1: Load-use hazard — consumer immediately after load
    TEST_CASE_START(1)
    li  x1, 0xCAFE
    sw  x1, 0(x10)
    lw  x2, 0(x10)          // load
    add x3, x2, x2          // use x2 one cycle later (hazard!)
    CHECK_REG(x3, 0x195FC)  // 0xCAFE*2

    // 2: Load then independent instruction then use (no stall needed)
    TEST_CASE_START(2)
    li  x1, 10
    sw  x1, 4(x10)
    lw  x2, 4(x10)
    addi x4, x0, 0          // independent
    add  x3, x2, x4
    CHECK_REG(x3, 10)

    // 3: ALU→ALU forwarding (EX→EX)
    TEST_CASE_START(3)
    li  x1, 3
    add x2, x1, x1          // x2 = 6
    add x3, x2, x2          // x3 = 12  (uses forwarded x2)
    CHECK_REG(x3, 12)

    // 4: ALU→ALU forwarding chain
    TEST_CASE_START(4)
    li  x1, 1
    add x2, x1, x1          // x2 = 2
    add x3, x2, x2          // x3 = 4
    add x4, x3, x3          // x4 = 8
    CHECK_REG(x4, 8)

    // 5: Branch after load (load result used in branch condition)
    TEST_CASE_START(5)
    li  x1, 1
    sw  x1, 8(x10)
    lw  x2, 8(x10)
    beq x2, x1, 5f          // branch using loaded value
    j   _fail_jump
5:

    // 6: Store immediately after load to same reg (load-use + forwarding to store)
    TEST_CASE_START(6)
    li  x1, 0xABCD
    sw  x1, 12(x10)
    lw  x2, 12(x10)
    sw  x2, 16(x10)         // store x2 right after load
    lw  x3, 16(x10)
    CHECK_REG(x3, 0xABCD)

RVTEST_PASS_LABEL
RVTEST_FAIL_TRAMPOLINE
RVTEST_CODE_END
RVTEST_DATA_BEGIN
RVTEST_DATA_END
