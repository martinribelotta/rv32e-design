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

/* ---- runtime helpers (sw/common/soc.c) ------------------------------- */
void     uart_putc(char c);
void     uart_puts(const char *s);
int      uart_rx_ready(void);
char     uart_getc(void);            /* blocks until a byte arrives */
void     uart_put_hex(uint32_t v);   /* prints 8 hex digits        */

void     gpio_set_dir(uint32_t mask);
void     gpio_write(uint32_t value);
uint32_t gpio_read(void);

void     delay(uint32_t count);      /* crude busy-wait loop       */

#endif /* SOC_H */
