/* crt0.S — minimal C startup for the rv32i-base RV32E SoC
 *
 *   1. set the stack pointer to the top of DRAM (__stack_top from the linker)
 *   2. copy .data from its DROM load image to its DRAM runtime address
 *   3. zero the .bss section
 *   4. call main()
 *   5. on return, write 1 to tohost (0x1FFC) — observed by the simulator as
 *      PASS, harmless on hardware (the address decodes to the peripheral
 *      window, so the store is dropped) — then spin forever.
 *
 * RV32E: only registers x0-x15 are available
 * (sp=x2, ra=x1, t0=x5, t1=x6, t2=x7, a0=x10).
 */
    .section .text.start, "ax"
    .global _start
_start:
    la      sp, __stack_top         /* stack grows down from top of DRAM */

    /* copy .data: DROM(__data_load) → DRAM(__data_start .. __data_end) */
    la      t0, __data_load
    la      t1, __data_start
    la      t2, __data_end
1:
    bgeu    t1, t2, 2f
    lw      a0, 0(t0)
    sw      a0, 0(t1)
    addi    t0, t0, 4
    addi    t1, t1, 4
    j       1b
2:
    /* zero .bss: for (p = __bss_start; p < __bss_end; p++) *p = 0 */
    la      t0, __bss_start
    la      t1, __bss_end
3:
    bgeu    t0, t1, 4f
    sw      zero, 0(t0)
    addi    t0, t0, 4
    j       3b
4:
    call    main                    /* run the application */

    li      t0, 1                   /* main returned: signal PASS to sim tohost */
    li      t1, 0x1FFC
    sw      t0, 0(t1)
5:
    j       5b                      /* halt */
    .size _start, .-_start
