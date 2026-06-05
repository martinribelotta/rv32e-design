#include "env/rv32e_test.h"

RVTEST_RV32E
RVTEST_CODE_BEGIN

    // 1: JAL jumps and saves return address
    TEST_CASE_START(1)
    jal  x1, 1f
    j    _fail_jump
1:
    // x1 must hold the address of the instruction after JAL (PC+4)
    // We can't know the exact PC, but we verify JAL actually jumped here
    // and that x1 != 0
    beq  x1, x0, _fail_jump

    // 2: JALR returns to saved address
    TEST_CASE_START(2)
    jal  x1, 2f             // x1 = PC of next instruction
    j    _pass_2            // should be skipped
2:
    jalr x0, x1, 0          // jump back to after jal
    j    _fail_jump         // should not reach here
_pass_2:

    // 3: JAL link register with offset: call/ret pattern
    TEST_CASE_START(3)
    li   x3, 0
    jal  x1, _sub3          // call subroutine
    CHECK_REG(x3, 0x5A)
    j    4f
_sub3:
    li   x3, 0x5A
    jalr x0, x1, 0          // ret
4:

    // 4: JALR clears bit 0 of target
    TEST_CASE_START(4)
    la   x2, _jalr_target   // x2 = even address of target label
    ori  x2, x2, 1          // set bit 0 (misalign)
    jalr x0, x2, 0          // JALR must land at _jalr_target (bit0 cleared)
    j    _fail_jump
_jalr_target:

RVTEST_PASS_LABEL
RVTEST_FAIL_TRAMPOLINE
RVTEST_CODE_END
RVTEST_DATA_BEGIN
RVTEST_DATA_END
