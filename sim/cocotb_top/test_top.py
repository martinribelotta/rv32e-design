"""
Top-level integration test for the rv32i-base SoC.

Runs a real C application (default: hello_uart) on the actual top.v — exercising
the IMEM, the DROM/DRAM split, the address decode and the UART peripheral — and
decodes the serial uart_tx stream to check the program's output byte-for-byte.

The PLL is bypassed via -DSIM_NO_PLL (see top.v) and the firmware is pre-loaded
into top.v's memories through their $readmemh init files (staged by the Makefile
as imem_seed.hex / drom_seed.hex).
"""
import os

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, ClockCycles, with_timeout

# What hello_uart prints. Override EXPECTED via the app if you change main.c.
EXPECTED = {
    "hello_uart": b"Hello from RV32E!\r\n",
    "echo":       b"echo ready\r\n",
}

# UART bit period in clk_core cycles: matches uart.v baud_div = CLK/BAUD - 1,
# so period = (div + 1) = CLK // BAUD.
BIT_CYCLES = 40_000_000 // 115_200          # = 347


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


@cocotb.test()
async def test_uart_output(dut):
    app = os.environ.get("APP", "hello_uart")
    expected = EXPECTED.get(app, EXPECTED["hello_uart"])

    # Idle inputs (UART line idles high; buttons released).
    dut.uart_rx.value = 1
    dut.buttons.value = 0

    # 40 MHz nominal — only cycle counts matter for the functional check.
    cocotb.start_soon(Clock(dut.clk, 25, units="ns").start())

    async def collect():
        got = bytearray()
        while len(got) < len(expected):
            got.append(await read_uart_byte(dut))
        return bytes(got)

    # Budget: reset (~2048 cyc) + 19 bytes * 10 bits * 347 cyc ≈ 68k cyc ≈ 1.7 ms.
    got = await with_timeout(collect(), 5, "ms")

    assert got == expected, (
        f"UART output mismatch for app '{app}':\n"
        f"  expected {expected!r}\n"
        f"  got      {got!r}"
    )
    dut._log.info(f"top-level UART output OK: {got!r}")
