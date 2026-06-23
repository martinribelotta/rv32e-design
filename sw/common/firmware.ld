/* firmware.ld — C linker script for the rv32i-base Harvard SoC.
 *
 * IMEM holds ONLY .text: the CPU fetches from it and CANNOT read it with load
 * instructions (dmem_addr ignores bit 12, so every load/store hits the data bus).
 *
 * The 4 KB data window is split (see rtl/top.v):
 *   DROM 0x1000-0x17FF : read-only init ROM — icebram-patchable like IMEM.
 *                        Holds .rodata and the load image (LMA) of .data.
 *   DRAM 0x1800-0x1EFF : writable RAM — .data (runtime/VMA), .bss and stack.
 *   0x1F00-0x1FFF      : peripherals.
 *
 * crt0 copies .data from its DROM load address to its DRAM runtime address and
 * zeroes .bss. .rodata is read in place from DROM.
 */
OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY {
    IMEM (rx)  : ORIGIN = 0x00000000, LENGTH = 4K
    DROM (r)   : ORIGIN = 0x00001000, LENGTH = 2K       /* 0x1000-0x17FF */
    DRAM (rw)  : ORIGIN = 0x00001800, LENGTH = 0x700    /* 0x1800-0x1EFF */
}

/* Top of stack: top of DRAM, just below the peripheral window at 0x1F00. */
__stack_top = ORIGIN(DRAM) + LENGTH(DRAM);

SECTIONS {
    .text : {
        KEEP(*(.text.start))        /* _start must be at IMEM 0x0 */
        *(.text .text.*)
    } > IMEM

    .rodata : {
        . = ALIGN(4);
        *(.rodata .rodata.*)
        *(.srodata .srodata.*)
        . = ALIGN(4);
    } > DROM

    /* .data: load image (LMA) in DROM, runtime (VMA) in DRAM. crt0 copies it. */
    .data : {
        . = ALIGN(4);
        __data_start = .;
        *(.data .data.*)
        *(.sdata .sdata.*)
        . = ALIGN(4);
        __data_end = .;
    } > DRAM AT> DROM
    __data_load = LOADADDR(.data);

    .bss (NOLOAD) : {
        . = ALIGN(4);
        __bss_start = .;
        *(.bss .bss.*)
        *(.sbss .sbss.*)
        *(COMMON)
        . = ALIGN(4);
        __bss_end = .;
    } > DRAM

    /* Guard against the DROM image (rodata + data LMA) overflowing 2 KB. */
    ASSERT(__data_load + (__data_end - __data_start) <= ORIGIN(DROM) + LENGTH(DROM),
           "DROM overflow: .rodata + .data load image exceed 2 KB")

    /DISCARD/ : { *(.comment) *(.riscv.attributes) *(.eh_frame) }
}
