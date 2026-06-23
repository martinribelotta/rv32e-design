/* echo — read bytes from the UART and echo them back.
 * Sends CRLF on carriage return so terminals show clean lines. */
#include "soc.h"

int main(void)
{
    uart_puts("echo ready\r\n");

    for (;;) {
        char c = uart_getc();
        uart_putc(c);
        if (c == '\r')
            uart_putc('\n');
    }
    return 0;
}
