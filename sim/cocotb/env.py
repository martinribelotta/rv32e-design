"""
pyuvm environment for rv32e_core functional tests.

Hierarchy:
  CpuEnv
    CpuAgent
      CpuDriver      (seqr → driver: loads firmware, starts BFM)
      ToHostMonitor  (watches for tohost write, ap → scoreboard)
    CpuScoreboard    (checks PASS / FAIL / TIMEOUT)

Sequence:
  FirmwareSeq  sends one  FirmwareSeqItem  carrying the hex file path.
"""

import os
import subprocess
import sys
import tempfile

import cocotb
from cocotb.triggers import RisingEdge, Timer
from pyuvm import (
    uvm_sequence_item,
    uvm_sequence,
    uvm_sequencer,
    uvm_driver,
    uvm_monitor,
    uvm_scoreboard,
    uvm_agent,
    uvm_env,
    uvm_test,
    uvm_analysis_port,
    uvm_tlm_analysis_fifo,
)

from bfm import CpuBFM
from mem_model import MemModel

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

# ---------------------------------------------------------------
# Compile helper
# ---------------------------------------------------------------
def compile_firmware(src_path, workdir):
    """Compile a .S test file to firmware.hex and data.hex."""
    cc = "riscv-none-elf-gcc"
    cflags = [
        "-march=rv32e_zicsr", "-mabi=ilp32e",
        "-nostdlib", "-nostartfiles",
        f"-I{os.path.join(ROOT, 'tests')}",
        "-T", os.path.join(ROOT, "sw", "link.ld"),
    ]
    elf  = os.path.join(workdir, "test.elf")
    hex_ = os.path.join(workdir, "firmware.hex")

    r = subprocess.run([cc] + cflags + [src_path, "-o", elf],
                       capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError(f"Compile failed:\n{r.stderr}")

    r = subprocess.run(
        [sys.executable,
         os.path.join(ROOT, "scripts", "elf2hex.py"),
         elf, hex_, "0x00000000", "1024"],
        capture_output=True, text=True
    )
    if r.returncode != 0:
        raise RuntimeError(f"elf2hex failed:\n{r.stderr}")

    data_hex = os.path.join(workdir, "data.hex")
    with open(data_hex, "w") as f:
        f.write("00000000\n" * 1024)

    return hex_, data_hex


# ---------------------------------------------------------------
# Sequence item & sequence
# ---------------------------------------------------------------
class FirmwareSeqItem(uvm_sequence_item):
    def __init__(self, name="firmware_item"):
        super().__init__(name)
        self.firmware_hex = ""   # path to compiled firmware.hex
        self.data_hex     = ""   # path to data.hex
        self.irq_cycle    = 20   # cycle at which to pulse IRQ (0 = no IRQ)
        self.max_cycles   = 50_000


class FirmwareSeq(uvm_sequence):
    def __init__(self, name="firmware_seq"):
        super().__init__(name)
        self.item = None          # set before calling start()

    async def body(self):
        await self.start_item(self.item)
        await self.finish_item(self.item)


# ---------------------------------------------------------------
# Driver — loads memory models, starts BFM, drives reset
# ---------------------------------------------------------------
class CpuDriver(uvm_driver):
    def build_phase(self):
        self.bfm = CpuBFM.get()

    async def run_phase(self):
        while True:
            item = await self.seq_item_port.get_next_item()
            await self._run_firmware(item)
            self.seq_item_port.item_done()

    async def _run_firmware(self, item: FirmwareSeqItem):
        bfm = self.bfm
        bfm.imem = MemModel()
        bfm.dmem = MemModel()
        while not bfm.tohost_q.empty():
            bfm.tohost_q.get_nowait()

        bfm.imem.load_hex(item.firmware_hex)
        bfm.dmem.load_hex(item.data_hex)

        bfm.start(irq_cycle=item.irq_cycle)
        await bfm.reset()


# ---------------------------------------------------------------
# Monitor — waits for tohost write, sends result to analysis port
# ---------------------------------------------------------------
class ToHostMonitor(uvm_monitor):
    def build_phase(self):
        self.ap  = uvm_analysis_port("ap", self)
        self.bfm = CpuBFM.get()

    async def run_phase(self):
        while True:
            value = await self.bfm.tohost_q.get()
            self.ap.write(value)


# ---------------------------------------------------------------
# Scoreboard — checks tohost value
# ---------------------------------------------------------------
class CpuScoreboard(uvm_scoreboard):
    def build_phase(self):
        self.fifo = uvm_tlm_analysis_fifo("fifo", self)
        self.result = None

    def connect_phase(self):
        # connected by CpuEnv
        pass

    async def run_phase(self):
        self.raise_objection()
        try:
            # Wait for a tohost write (the test's run_phase drops objection on timeout)
            value = await self.fifo.get()
            if value == 1:
                self.result = ("PASS", None)
                self.logger.info("PASS")
            else:
                test_num = value >> 1
                self.result = ("FAIL", test_num)
                self.logger.error(f"FAIL at test case {test_num} (tohost=0x{value:08x})")
        finally:
            self.drop_objection()

    def check_phase(self):
        if self.result is None:
            self.logger.error("TIMEOUT — no tohost write observed")
            raise AssertionError("TIMEOUT")
        status, n = self.result
        if status != "PASS":
            raise AssertionError(f"FAIL at test case {n}")


# ---------------------------------------------------------------
# Agent
# ---------------------------------------------------------------
class CpuAgent(uvm_agent):
    def build_phase(self):
        self.seqr    = uvm_sequencer("seqr", self)
        self.driver  = CpuDriver("driver", self)
        self.monitor = ToHostMonitor("monitor", self)

    def connect_phase(self):
        self.driver.seq_item_port.connect(self.seqr.seq_item_export)


# ---------------------------------------------------------------
# Environment
# ---------------------------------------------------------------
class CpuEnv(uvm_env):
    def build_phase(self):
        self.agent = CpuAgent("agent", self)
        self.scoreboard = CpuScoreboard("scoreboard", self)

    def connect_phase(self):
        self.agent.monitor.ap.connect(self.scoreboard.fifo.analysis_export)


# ---------------------------------------------------------------
# Base test
# ---------------------------------------------------------------
class BaseRv32Test(uvm_test):
    """
    Subclass this and set:
      firmware_src = "tests/add.S"   (path relative to project root)
      irq_cycle    = 20              (0 = no IRQ)
    """
    firmware_src = ""
    irq_cycle    = 20

    def build_phase(self):
        self.env = CpuEnv("env", self)
        # DUT is already connected to BFM in _run() before uvm_root.run_test()
        # clears pyuvm singletons (which would erase ConfigDB entries).

    async def run_phase(self):
        self.raise_objection()
        workdir = tempfile.mkdtemp(prefix="rv32e_cocotb_")
        try:
            src = os.path.join(ROOT, self.firmware_src)
            fw_hex, data_hex = compile_firmware(src, workdir)

            item = FirmwareSeqItem()
            item.firmware_hex = fw_hex
            item.data_hex     = data_hex
            item.irq_cycle    = self.irq_cycle

            seq = FirmwareSeq()
            seq.item = item
            await seq.start(self.env.agent.seqr)

            # Wait for scoreboard to observe tohost (it raises its own objection)
            await Timer(item.max_cycles * 10 + 100, unit="ns")
        finally:
            import shutil
            shutil.rmtree(workdir, ignore_errors=True)
            self.drop_objection()
