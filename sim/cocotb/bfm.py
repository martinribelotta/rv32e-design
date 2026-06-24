"""
Bus Functional Model for rv32e_core.

Provides:
  - Clock generation (10 ns period → 100 MHz sim; wall-clock time is separate from
    the RTL 40 MHz — only relative timing matters for functional tests)
  - Reset sequencing
  - IMEM response: 1-cycle registered read (models SB_RAM40_4K behaviour)
  - DMEM response: 1-cycle registered read + byte-enable write
  - IRQ pulse
  - tohost detection (write to DMEM word DMEM_DEPTH-1)
"""

import cocotb
import cocotb.queue
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from mem_model import MemModel


def _safe_int(sig, default=0):
    """Convert a cocotb signal value to int; return default if X/Z."""
    try:
        return int(sig.value)
    except ValueError:
        return default


class CpuBFM:
    """Singleton BFM — call CpuBFM.get() to retrieve the shared instance."""
    _instance = None

    @classmethod
    def get(cls):
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance

    @classmethod
    def reset_instance(cls):
        cls._instance = None

    def __init__(self):
        self.dut = None
        self.imem = MemModel()
        self.dmem = MemModel()
        # cocotb.queue.Queue (not asyncio.Queue) — works inside the simulator event loop
        self.tohost_q: cocotb.queue.Queue = cocotb.queue.Queue()
        self._tasks = []

    def connect(self, dut):
        self.dut = dut
        self.tohost_q = cocotb.queue.Queue()   # fresh queue per test run

    # -------------------------------------------------------
    # Startup helpers
    # -------------------------------------------------------
    def start(self, irq_cycle=20):
        """Launch all BFM coroutines.  Call once after connect()."""
        dut = self.dut
        dut.timer_irq.value = 0          # no machine-timer source in core-level tests
        cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
        self._tasks = [
            cocotb.start_soon(self._serve_imem()),
            cocotb.start_soon(self._serve_dmem()),
        ]
        if irq_cycle > 0:
            cocotb.start_soon(self._pulse_irq(irq_cycle))

    async def reset(self, cycles=4):
        dut = self.dut
        dut.rst_n.value = 0
        dut.irq.value   = 0
        for _ in range(cycles):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1

    # -------------------------------------------------------
    # IMEM — 1-cycle latency (synchronous read model)
    # Drive rdata = mem[addr] AFTER each rising edge;
    # DUT samples it on the NEXT rising edge.
    # -------------------------------------------------------
    async def _serve_imem(self):
        dut = self.dut
        while True:
            await RisingEdge(dut.clk)
            addr = _safe_int(dut.imem_addr) % self.imem.depth
            dut.imem_rdata.value = self.imem.read(addr)

    # -------------------------------------------------------
    # DMEM — 1-cycle latency read + byte-enable write.
    # Read-before-write semantics: rdata driven from current address,
    # then write is applied (matches SB_RAM40_4K default mode).
    # Tohost is DMEM word (depth-1); written value is pushed to tohost_q.
    # -------------------------------------------------------
    async def _serve_dmem(self):
        dut = self.dut
        while True:
            await RisingEdge(dut.clk)
            addr = _safe_int(dut.dmem_addr) % self.dmem.depth
            we   = _safe_int(dut.dmem_we)

            # Drive read data (1-cycle registered output)
            dut.dmem_rdata.value = self.dmem.read(addr)

            # Process write
            if we and _safe_int(dut.rst_n):
                wdata = _safe_int(dut.dmem_wdata)
                self.dmem.write(addr, wdata, we)
                if addr == self.dmem.depth - 1:   # tohost
                    self.tohost_q.put_nowait(wdata)

    # -------------------------------------------------------
    # IRQ — single 1-cycle pulse at the given cycle count
    # -------------------------------------------------------
    async def _pulse_irq(self, cycle):
        dut = self.dut
        for _ in range(cycle):
            await RisingEdge(dut.clk)
        dut.irq.value = 1
        await RisingEdge(dut.clk)
        dut.irq.value = 0
