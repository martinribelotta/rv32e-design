/* timer_blink — toggle LED0 from a machine-timer interrupt (MTIP).
 *
 * Shows the mtimer flow: arm mtimecmp, enable the timer interrupt, and let the
 * ISR re-arm the comparator each tick. main() does no work itself.
 *
 * The ISR re-arms relative to the previous deadline (deadline += INTERVAL), so
 * the interrupt grid does not drift. Note that the actual interrupt period is
 * INTERVAL plus a fixed interrupt-entry/handler overhead (~120 clk on this
 * core): the comparator only advances once the ISR runs, which happens a fixed
 * number of cycles after the deadline is crossed. The overhead is constant, so
 * the rate is stable; raise INTERVAL until it is negligible.
 *
 * INTERVAL is sized for simulation (1.25 ms @ 40 MHz). For a human-visible LED
 * on hardware raise it, e.g. 4000000 (100 ms → 5 Hz). */
#include "soc.h"

#define INTERVAL 50000u          /* clk ticks between toggles */

static volatile uint32_t ticks;     /* incremented on every timer interrupt */
static uint64_t          deadline;  /* next mtimecmp value, tracked in software */

void __attribute__((interrupt("machine"))) timer_isr(void)
{
    if (csr_read(mcause) == MCAUSE_M_TIMER) {
        deadline += INTERVAL;          /* advance from the previous deadline */
        mtimer_set_cmp(deadline);      /* re-arm (relative, so no drift)     */
        ticks++;
        GPIO_OUT ^= 1u;                /* toggle LED0 */
    }
}

int main(void)
{
    gpio_set_dir(0xFF);                          /* LEDs as outputs */
    csr_write(mtvec, (uint32_t)&timer_isr);      /* trap vector (direct mode) */
    deadline = mtime_now() + INTERVAL;
    mtimer_set_cmp(deadline);                    /* first deadline */
    csr_set(mie, MIE_MTIE);                      /* enable machine timer IRQ */
    csr_set(mstatus, MSTATUS_MIE);               /* global interrupt enable */

    for (;;)                                     /* the ISR does all the work */
        ;
    return 0;
}
