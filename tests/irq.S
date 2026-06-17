#include "env/rv32e_test.h"

RVTEST_RV32E
RVTEST_CODE_BEGIN

    // Configure interrupt handler — use la so the address is computed by the assembler
    la   x1, _handler
    csrw mtvec, x1

    // Enable external IRQ (MEIE) and global MIE
    li   x1, 2048          # MEIE = bit 11
    csrw mie, x1
    li   x1, 8             # MIE = bit 3
    csrw mstatus, x1

    // Clear handler flag
    li   x5, 0

    // Wait for the external IRQ to arrive (BFM pulses irq at cycle ~30)
    li   x2, 200
wait_loop:
    addi x2, x2, -1
    bnez x2, wait_loop

    // Interrupt handler should set x5 to 1
    beq  x5, x0, _fail_jump
    j    _pass

    .align 2
_handler:
    li   x5, 1
    mret

RVTEST_PASS_LABEL
RVTEST_FAIL_TRAMPOLINE
RVTEST_CODE_END
RVTEST_DATA_BEGIN
RVTEST_DATA_END
