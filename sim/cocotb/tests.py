"""
cocotb entry points for rv32e_core functional tests.

Each @cocotb.test() corresponds to one firmware file.
Filter with:  COCOTB_TEST_FILTER=test_add make -C sim/cocotb
"""

import cocotb
from pyuvm import uvm_root

from bfm import CpuBFM
from env import BaseRv32Test


# ---------------------------------------------------------------
# Concrete test classes — one per firmware file
# ---------------------------------------------------------------
class AddTest(BaseRv32Test):
    firmware_src = "tests/add.S";       irq_cycle = 0

class AddiTest(BaseRv32Test):
    firmware_src = "tests/addi.S";      irq_cycle = 0

class SubTest(BaseRv32Test):
    firmware_src = "tests/sub.S";       irq_cycle = 0

class LogicalTest(BaseRv32Test):
    firmware_src = "tests/logical.S";   irq_cycle = 0

class ShiftTest(BaseRv32Test):
    firmware_src = "tests/shift.S";     irq_cycle = 0

class SltTest(BaseRv32Test):
    firmware_src = "tests/slt.S";       irq_cycle = 0

class LuiAuipcTest(BaseRv32Test):
    firmware_src = "tests/lui_auipc.S"; irq_cycle = 0

class BranchTest(BaseRv32Test):
    firmware_src = "tests/branch.S";    irq_cycle = 0

class JalJalrTest(BaseRv32Test):
    firmware_src = "tests/jal_jalr.S";  irq_cycle = 0

class LoadStoreTest(BaseRv32Test):
    firmware_src = "tests/load_store.S"; irq_cycle = 0

class HazardTest(BaseRv32Test):
    firmware_src = "tests/hazard.S";    irq_cycle = 0

class IrqTest(BaseRv32Test):
    firmware_src = "tests/irq.S";       irq_cycle = 30


# ---------------------------------------------------------------
# cocotb test entry points — one per test class
# ---------------------------------------------------------------
async def _run(dut, cls):
    CpuBFM.reset_instance()
    CpuBFM.get().connect(dut)
    await uvm_root().run_test(cls.__name__)


@cocotb.test()
async def test_add(dut):        await _run(dut, AddTest)

@cocotb.test()
async def test_addi(dut):       await _run(dut, AddiTest)

@cocotb.test()
async def test_sub(dut):        await _run(dut, SubTest)

@cocotb.test()
async def test_logical(dut):    await _run(dut, LogicalTest)

@cocotb.test()
async def test_shift(dut):      await _run(dut, ShiftTest)

@cocotb.test()
async def test_slt(dut):        await _run(dut, SltTest)

@cocotb.test()
async def test_lui_auipc(dut):  await _run(dut, LuiAuipcTest)

@cocotb.test()
async def test_branch(dut):     await _run(dut, BranchTest)

@cocotb.test()
async def test_jal_jalr(dut):   await _run(dut, JalJalrTest)

@cocotb.test()
async def test_load_store(dut): await _run(dut, LoadStoreTest)

@cocotb.test()
async def test_hazard(dut):     await _run(dut, HazardTest)

@cocotb.test()
async def test_irq(dut):        await _run(dut, IrqTest)
