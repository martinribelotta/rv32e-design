/* timer_blink — toggle LED0 from a machine-timer interrupt (MTIP).
 *
 * Shows the mtimer flow: arm mtimecmp, enable the timer interrupt, and let the
 * ISR re-arm the comparator each tick. main() does no work itself.
 *
 * The ISR re-arms relative to the deadline that fired (mtimecmp += INTERVAL,
 * read back with mtimer_get_cmp()), so the interrupt grid is exact and does NOT
 * drift — the period is exactly INTERVAL regardless of interrupt-entry latency.
 * (Re-arming with mtime_now() + INTERVAL instead would drift by that latency.)
 *
 * INTERVAL is sized for simulation (1.25 ms @ 40 MHz). For a human-visible LED
 * on hardware raise it, e.g. 4000000 (100 ms → 5 Hz). */
#include "soc.h"

#define INTERVAL 50000u          /* clk ticks between toggles */

static volatile uint32_t ticks;     /* incremented on every timer interrupt */

void __attribute__((interrupt("machine"))) timer_isr(void)
{
    if (csr_read(mcause) == MCAUSE_M_TIMER) {
        uint64_t now = mtimer_get_cmp();    /* read the current mtimecmp (not mtime) */
        uint64_t deadline = now + INTERVAL; /* next deadline */
        mtimer_set_cmp(deadline);           /* re-arm (relative, so no drift)     */
        ticks++;
        GPIO_OUT ^= 1u;                /* toggle LED0 */
    }
}

int main(void)
{
    gpio_set_dir(0xFF);                          /* LEDs as outputs */
    csr_write(mtvec, (uint32_t)&timer_isr);      /* trap vector (direct mode) */
    uint64_t deadline = mtime_now() + INTERVAL;
    mtimer_set_cmp(deadline);                    /* first deadline */
    csr_set(mie, MIE_MTIE);                      /* enable machine timer IRQ */
    csr_set(mstatus, MSTATUS_MIE);               /* global interrupt enable */

    for (;;)                                     /* the ISR does all the work */
        ;
    return 0;
}
