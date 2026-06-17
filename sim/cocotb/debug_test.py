import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import subprocess, sys, os, tempfile

ROOT = "/home/martin/rv32i-base"

def compile_fw(src, workdir):
    cc = "riscv-none-elf-gcc"
    flags = ["-march=rv32e_zicsr", "-mabi=ilp32e", "-nostdlib", "-nostartfiles",
             f"-I{ROOT}/tests", "-T", f"{ROOT}/sw/link.ld"]
    elf = f"{workdir}/test.elf"
    hex_ = f"{workdir}/firmware.hex"
    r = subprocess.run([cc]+flags+[src, "-o", elf], capture_output=True, text=True)
    if r.returncode: raise RuntimeError(r.stderr)
    r = subprocess.run([sys.executable, f"{ROOT}/scripts/elf2hex.py", elf, hex_, "0x0", "1024"],
                       capture_output=True, text=True)
    if r.returncode: raise RuntimeError(r.stderr)
    with open(f"{workdir}/data.hex","w") as f: f.write("00000000\n"*1024)
    return hex_

@cocotb.test()
async def test_add_bare(dut):
    """Minimal cocotb test without pyuvm."""
    workdir = tempfile.mkdtemp()
    fw = compile_fw(f"{ROOT}/tests/add.S", workdir)
    
    # Load memory
    mem = [0]*1024
    with open(fw) as f:
        for i,line in enumerate(f):
            line=line.strip()
            if line and i < 1024: mem[i]=int(line,16)
    dmem = [0]*1024
    
    cocotb.start_soon(Clock(dut.clk, 10, "ns").start())
    dut.rst_n.value = 0; dut.irq.value = 0
    for _ in range(4): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    
    tohost = None
    for cycle in range(50000):
        await RisingEdge(dut.clk)
        try:
            ia = int(dut.imem_addr.value) % 1024
            dut.imem_rdata.value = mem[ia]
            da = int(dut.dmem_addr.value) % 1024
            we = int(dut.dmem_we.value)
            dut.dmem_rdata.value = dmem[da]
            if we and int(dut.rst_n.value):
                wd = int(dut.dmem_wdata.value)
                for b in range(4):
                    if we & (1<<b):
                        dmem[da] = (dmem[da] & ~(0xFF<<(b*8))) | ((wd>>(b*8)&0xFF)<<(b*8))
                if da == 1023:
                    tohost = wd
                    break
        except ValueError:
            pass
    
    import shutil; shutil.rmtree(workdir, ignore_errors=True)
    
    assert tohost == 1, f"FAIL: tohost=0x{tohost:08x}" if tohost else "TIMEOUT"
    cocotb.log.info("PASS: add test")
