"""
Top-level integration tests for the rv32i-base SoC.

Runs a real C application on the actual top.v — exercising the IMEM, the
DROM/DRAM split, the address decode and the peripherals — and observes the
external pins. The PLL is bypassed via -DSIM_NO_PLL (see top.v) and the
firmware is pre-loaded into top.v's memories through their $readmemh init
files (staged by the Makefile as imem_seed.hex / drom_seed.hex).

The active test is selected by APP (set by the Makefile):
  hello_uart / echo  → decode the uart_tx stream and check the banner
  timer_blink        → check LED0 toggles at the machine-timer interval
"""
import os

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, ClockCycles, with_timeout
from cocotb.utils import get_sim_time

APP = os.environ.get("APP", "hello_uart")

# Expected UART banner per app (uart_tx test).
EXPECTED = {
    "hello_uart": b"Hello from RV32E!\r\n",
    "echo":       b"echo ready\r\n",
}

# UART bit period in clk_core cycles: matches uart.v baud_div = CLK/BAUD - 1,
# so period = (div + 1) = CLK // BAUD.
BIT_CYCLES = 40_000_000 // 115_200          # = 347

CLK_NS = 25                                 # 25 ns clock → 40 MHz
TIMER_INTERVAL = 50_000                     # must match timer_blink/main.c


async def read_uart_byte(dut):
    """Decode one 8N1 byte from uart_tx, sampling each bit at its centre."""
    await FallingEdge(dut.uart_tx)                              # start bit edge
    await ClockCycles(dut.clk, BIT_CYCLES + BIT_CYCLES // 2)    # centre of bit 0
    value = 0
    for i in range(8):                                          # LSB first
        if dut.uart_tx.value:
            value |= (1 << i)
        await ClockCycles(dut.clk, BIT_CYCLES)
    return value                                                # now in stop bit


@cocotb.test(skip=APP not in EXPECTED)
async def test_uart_output(dut):
    expected = EXPECTED[APP]

    dut.uart_rx.value = 1                       # UART line idles high
    dut.buttons.value = 0
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units="ns").start())

    async def collect():
        got = bytearray()
        while len(got) < len(expected):
            got.append(await read_uart_byte(dut))
        return bytes(got)

    got = await with_timeout(collect(), 5, "ms")
    assert got == expected, (
        f"UART output mismatch for app '{APP}':\n"
        f"  expected {expected!r}\n  got      {got!r}"
    )
    dut._log.info(f"top-level UART output OK: {got!r}")


@cocotb.test(skip=APP != "timer_blink")
async def test_timer_blink(dut):
    dut.uart_rx.value = 1
    dut.buttons.value = 0
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units="ns").start())

    # Measure the real interrupt grid at the mtimer's timer_irq rising edges
    # (one per deadline). The example re-arms with mtimecmp += INTERVAL, so the
    # grid must be exact: every period equals INTERVAL and error never accumulates.
    await with_timeout(RisingEdge(dut.mtimer0.timer_irq), 3, "ms")
    t0 = get_sim_time("ns")
    prev = t0
    periods = []
    for k in range(1, 6):
        await with_timeout(RisingEdge(dut.mtimer0.timer_irq), 3, "ms")
        t = get_sim_time("ns")
        periods.append(round((t - prev) / CLK_NS))
        prev = t
    cumulative_drift = round((prev - t0) / CLK_NS) - len(periods) * TIMER_INTERVAL

    dut._log.info(
        f"timer_blink interrupt periods {periods} cyc, "
        f"cumulative drift after {len(periods)} periods = {cumulative_drift}"
    )
    assert all(p == TIMER_INTERVAL for p in periods), (
        f"period != INTERVAL ({TIMER_INTERVAL}): {periods}"
    )
    assert cumulative_drift == 0, f"timer drifts: {cumulative_drift} cyc accumulated"
