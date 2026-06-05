//
// RV32E test environment — compatible with riscv-tests style macros.
// Pass/fail signalled via write to tohost (address 0x00001000 in DMEM).
//   tohost = 1  → PASS
//   tohost = <n><<1 | 1 → FAIL (n = test number that failed)
//

#ifndef RV32E_TEST_H
#define RV32E_TEST_H

// Last word of DMEM (1024 words × 4 bytes = 0x1000..0x1FFF → last word at 0x1FFC).
// Keeping tohost away from address 0 avoids collisions with load/store tests.
#define TOHOST_ADDR 0x00001FFC

// -------------------------------------------------------
// Boilerplate: entry point, stack, tohost section
// -------------------------------------------------------
#define RVTEST_RV32E                        \
    .section .text;                         \
    .globl _start;                          \
_start:

#define RVTEST_CODE_BEGIN   /* nothing extra */

#define RVTEST_DATA_BEGIN   .section .data; .align 2;
#define RVTEST_DATA_END     /* nothing */

// Test counter: x15 holds current test number
#define TESTNUM x15

// -------------------------------------------------------
// Per-test check macros
// -------------------------------------------------------

// Set current test number
#define TEST_CASE_START(n) \
    li   TESTNUM, n;

// Check: if register reg != expected → branch to _fail_jump
// Uses x13 as scratch
#define CHECK_REG(reg, expected)    \
    li   x13, expected;             \
    bne  reg, x13, _fail_jump;

// RVTEST_PASS: normal fall-through at end of tests jumps here.
// Place this BEFORE RVTEST_FAIL_TRAMPOLINE so flow doesn't fall into fail.
#define RVTEST_PASS_LABEL               \
    j    _pass;

// Shared fail trampoline + pass label.
// Usage in each .S file:
//   ... last CHECK_REG ...
//   RVTEST_PASS_LABEL          ← jump over the trampoline
//   RVTEST_FAIL_TRAMPOLINE     ← fail handler (branched to by CHECK_REG)
//   RVTEST_CODE_END            ← _pass label + PASS write
#define RVTEST_FAIL_TRAMPOLINE              \
_fail_jump:                                 \
    slli x15, x15, 1;                       \
    ori  x15, x15, 1;                       \
    li   x2, TOHOST_ADDR;                   \
    sw   x15, 0(x2);                        \
_hang_fail:                                 \
    j    _hang_fail;

#define RVTEST_CODE_END         \
_pass:                          \
    li   x1, 1;                 \
    li   x2, TOHOST_ADDR;       \
    sw   x1, 0(x2);             \
_hang_pass:                     \
    j    _hang_pass;

#endif // RV32E_TEST_H
