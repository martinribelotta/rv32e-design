/* soc.h — memory-mapped peripheral registers + runtime helpers.
 * Addresses come from rtl/top.v (DMEM byte addresses, base 0x1000).
 */
#ifndef SOC_H
#define SOC_H

#include <stdint.h>

/* ---- GPIO (8-bit) ---------------------------------------------------- */
#define GPIO_OUT   (*(volatile uint32_t *)0x1F00u)  /* output data    (R/W) */
#define GPIO_IN    (*(volatile uint32_t *)0x1F04u)  /* input data     (R)   */
#define GPIO_DIR   (*(volatile uint32_t *)0x1F08u)  /* 1 = output     (R/W) */

/* ---- UART (8N1) ------------------------------------------------------ */
#define UART_DATA  (*(volatile uint32_t *)0x1F40u)  /* W = TX byte, R = RX byte */
#define UART_STAT  (*(volatile uint32_t *)0x1F44u)  /* status flags   (R)   */
#define UART_BAUD  (*(volatile uint32_t *)0x1F48u)  /* divisor[15:0]  (R/W) */

#define UART_TX_READY  0x1u   /* STATUS bit0: TX idle — safe to write DATA */
#define UART_RX_VALID  0x2u   /* STATUS bit1: an RX byte is waiting        */

/* ---- Machine timer (mtime / mtimecmp) -------------------------------- */
#define MTIME_LO     (*(volatile uint32_t *)0x1F50u)  /* mtime[31:0]     (R/W) */
#define MTIME_HI     (*(volatile uint32_t *)0x1F54u)  /* mtime[63:32]    (R/W) */
#define MTIMECMP_LO  (*(volatile uint32_t *)0x1F58u)  /* mtimecmp[31:0]  (R/W) */
#define MTIMECMP_HI  (*(volatile uint32_t *)0x1F5Cu)  /* mtimecmp[63:32] (R/W) */

#define CLK_HZ        40000000u           /* clk_core; mtime ticks at this rate */
#define TICKS_PER_US  (CLK_HZ / 1000000u) /* = 40 */

/* ---- CSR access + machine-interrupt bits ----------------------------- */
#define csr_read(csr) ({ uint32_t __v; \
    __asm__ volatile ("csrr %0, " #csr : "=r"(__v)); __v; })
#define csr_write(csr, val) __asm__ volatile ("csrw " #csr ", %0" :: "r"(val))
#define csr_set(csr, val)   __asm__ volatile ("csrs " #csr ", %0" :: "r"(val))
#define csr_clear(csr, val) __asm__ volatile ("csrc " #csr ", %0" :: "r"(val))

#define MSTATUS_MIE     (1u << 3)    /* global machine interrupt enable      */
#define MIE_MTIE        (1u << 7)    /* machine timer interrupt enable       */
#define MIE_MEIE        (1u << 11)   /* machine external interrupt enable    */
#define MCAUSE_M_TIMER  0x80000007u  /* mcause for a machine timer interrupt */

/* ---- runtime helpers (sw/common/soc.c) ------------------------------- */
void     uart_putc(char c);
void     uart_puts(const char *s);
int      uart_rx_ready(void);
char     uart_getc(void);            /* blocks until a byte arrives */
void     uart_put_hex(uint32_t v);   /* prints 8 hex digits        */

void     gpio_set_dir(uint32_t mask);
void     gpio_write(uint32_t value);
uint32_t gpio_read(void);

/* --- timing (mtime-based; precise) --- */
uint64_t mtime_now(void);            /* current 64-bit machine time      */
uint64_t mtimer_get_cmp(void);       /* current mtimecmp                 */
void     mtimer_set_cmp(uint64_t v); /* glitch-free mtimecmp write       */
void     delay_ticks(uint32_t t);    /* spin for t clk ticks             */
void     delay_us(uint32_t us);      /* spin for us microseconds         */
void     delay_ms(uint32_t ms);      /* spin for ms milliseconds         */

void     delay(uint32_t count);      /* crude busy-wait loop (no timer)  */

#endif /* SOC_H */
