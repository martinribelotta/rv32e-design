/* soc.c — minimal runtime for the rv32i-base SoC (UART + GPIO + delay). */
#include "soc.h"

void uart_putc(char c)
{
    while (!(UART_STAT & UART_TX_READY))   /* wait until TX is idle */
        ;
    UART_DATA = (uint32_t)(uint8_t)c;
}

void uart_puts(const char *s)
{
    while (*s)
        uart_putc(*s++);
}

int uart_rx_ready(void)
{
    return (UART_STAT & UART_RX_VALID) != 0;
}

char uart_getc(void)
{
    while (!(UART_STAT & UART_RX_VALID))   /* block until a byte arrives */
        ;
    return (char)(UART_DATA & 0xFFu);      /* reading DATA clears rx_valid */
}

void uart_put_hex(uint32_t v)
{
    static const char hex[] = "0123456789abcdef";
    int i;
    for (i = 28; i >= 0; i -= 4)
        uart_putc(hex[(v >> i) & 0xFu]);
}

void gpio_set_dir(uint32_t mask) { GPIO_DIR = mask; }
void gpio_write(uint32_t value)  { GPIO_OUT = value; }
uint32_t gpio_read(void)         { return GPIO_IN; }

uint64_t mtime_now(void)
{
    uint32_t hi, lo, hi2;
    do {                                /* re-read on rollover of the low word */
        hi  = MTIME_HI;
        lo  = MTIME_LO;
        hi2 = MTIME_HI;
    } while (hi != hi2);
    return ((uint64_t)hi << 32) | lo;
}

uint64_t mtimer_get_cmp(void)
{
    /* mtimecmp does not auto-increment, so a plain read is safe. */
    return ((uint64_t)MTIMECMP_HI << 32) | MTIMECMP_LO;
}

void mtimer_set_cmp(uint64_t v)
{
    MTIMECMP_LO = 0xFFFFFFFFu;           /* no spurious match while updating */
    MTIMECMP_HI = (uint32_t)(v >> 32);
    MTIMECMP_LO = (uint32_t)v;
}

void delay_ticks(uint32_t t)
{
    uint64_t target = mtime_now() + t;
    while (mtime_now() < target)
        ;
}

void delay_us(uint32_t us) { delay_ticks(us * TICKS_PER_US); }
void delay_ms(uint32_t ms) { delay_ticks(ms * TICKS_PER_US * 1000u); }

void delay(uint32_t count)
{
    volatile uint32_t i;
    for (i = 0; i < count; i++)
        ;
}
