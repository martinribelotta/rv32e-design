/* blink — rotate a single lit LED across the 8 GPIO outputs.
 * Pure code, no static data: the simplest smoke test of the C flow. */
#include "soc.h"

int main(void)
{
    uint32_t pattern = 0x01;

    gpio_set_dir(0xFF);          /* all 8 GPIO pins as outputs (LEDs) */

    for (;;) {
        gpio_write(pattern);
        pattern = ((pattern << 1) | (pattern >> 7)) & 0xFF;   /* rotate left */
        delay(2000000);
    }
    return 0;
}
