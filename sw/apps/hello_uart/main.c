/* hello_uart — print a greeting over UART at 115200 8N1.
 * The string literal lives in .rodata (DMEM), so this exercises the
 * DMEM icebram-patch path end to end. */
#include "soc.h"

int main(void)
{
    uart_puts("Hello from RV32E!\r\n");

    for (;;)
        ;
    return 0;
}
