#!/usr/bin/env python3
"""
Compile each test in tests/*.S, simulate with iverilog/vvp, report PASS/FAIL.
Run from the project root: python3 scripts/run_tests.py
"""
import subprocess, sys, os, tempfile, shutil, glob, argparse

ROOT      = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TESTS_DIR = os.path.join(ROOT, "tests")
RTL_DIR   = os.path.join(ROOT, "rtl")
SIM_DIR   = os.path.join(ROOT, "sim")
SCRIPTS   = os.path.join(ROOT, "scripts")

CC      = "riscv-none-elf-gcc"
OBJCOPY = "riscv-none-elf-objcopy"

CFLAGS = [
    "-march=rv32e", "-mabi=ilp32e",
    "-nostdlib", "-nostartfiles",
    f"-I{TESTS_DIR}",
    "-T", os.path.join(ROOT, "sw", "link.ld"),
]

SIM_SRCS = [
    os.path.join(RTL_DIR, "rv32i_pkg.v"),
    os.path.join(RTL_DIR, "bram_dp.v"),
    os.path.join(RTL_DIR, "alu.v"),
    os.path.join(RTL_DIR, "regfile.v"),
    os.path.join(RTL_DIR, "decoder.v"),
    os.path.join(RTL_DIR, "rv32i_core.v"),
    os.path.join(SIM_DIR, "tb_rv32i.v"),
]

GREEN  = "\033[32m"
RED    = "\033[31m"
YELLOW = "\033[33m"
RESET  = "\033[0m"


def run(cmd, cwd=None, capture=True):
    r = subprocess.run(cmd, cwd=cwd, capture_output=capture, text=True)
    return r.returncode, r.stdout, r.stderr


def compile_test(src, workdir):
    elf  = os.path.join(workdir, "test.elf")
    hex_ = os.path.join(workdir, "firmware.hex")

    rc, _, err = run([CC] + CFLAGS + [src, "-o", elf])
    if rc != 0:
        return None, f"compile error:\n{err}"

    rc, _, err = run([
        sys.executable, os.path.join(SCRIPTS, "elf2hex.py"),
        elf, hex_, "0x00000000", "1024"
    ])
    if rc != 0:
        return None, f"elf2hex error:\n{err}"

    # Empty data.hex (DMEM initialised to 0)
    data_hex = os.path.join(workdir, "data.hex")
    with open(data_hex, "w") as f:
        f.write("00000000\n" * 1024)

    return hex_, None


def build_sim(workdir):
    vvp = os.path.join(workdir, "sim.vvp")
    rc, _, err = run(
        ["iverilog", "-g2005", "-I", RTL_DIR, "-o", vvp] + SIM_SRCS,
        cwd=workdir
    )
    if rc != 0:
        return None, f"iverilog error:\n{err}"
    return vvp, None


def run_sim(vvp, workdir):
    rc, stdout, _ = run(["vvp", vvp], cwd=workdir)
    for line in stdout.strip().splitlines():
        if line.startswith("PASS") or line.startswith("FAIL") or line.startswith("TIMEOUT"):
            return line
    return stdout.strip().splitlines()[-1] if stdout.strip() else ""


def main():
    parser = argparse.ArgumentParser(description="Run RV32E core tests")
    parser.add_argument("tests", nargs="*", help="specific test names (without .S)")
    parser.add_argument("-v", "--verbose", action="store_true")
    args = parser.parse_args()

    patterns = args.tests or []
    all_srcs = sorted(glob.glob(os.path.join(TESTS_DIR, "*.S")))
    if patterns:
        all_srcs = [s for s in all_srcs
                    if os.path.splitext(os.path.basename(s))[0] in patterns]

    if not all_srcs:
        print("No tests found.")
        sys.exit(1)

    passed, failed, errors = [], [], []

    for src in all_srcs:
        name = os.path.splitext(os.path.basename(src))[0]
        workdir = tempfile.mkdtemp(prefix=f"rv32e_{name}_")
        try:
            _, err = compile_test(src, workdir)
            if err:
                errors.append((name, err))
                print(f"  {YELLOW}ERROR{RESET}  {name}: {err.splitlines()[0]}")
                continue

            vvp, err = build_sim(workdir)
            if err:
                errors.append((name, err))
                print(f"  {YELLOW}ERROR{RESET}  {name}: {err.splitlines()[0]}")
                continue

            result = run_sim(vvp, workdir)

            if result == "PASS":
                passed.append(name)
                print(f"  {GREEN}PASS{RESET}   {name}")
            elif result.startswith("FAIL"):
                failed.append((name, result))
                print(f"  {RED}FAIL{RESET}   {name}: {result}")
            else:
                errors.append((name, result))
                print(f"  {YELLOW}ERROR{RESET}  {name}: {result or '(no output)'}")

            if args.verbose and result != "PASS":
                print(f"         workdir: {workdir}")
        finally:
            if not args.verbose or result == "PASS":
                shutil.rmtree(workdir, ignore_errors=True)

    total = len(passed) + len(failed) + len(errors)
    print()
    print(f"Results: {len(passed)}/{total} passed", end="")
    if failed:
        print(f"  |  {len(failed)} failed: {', '.join(n for n,_ in failed)}", end="")
    if errors:
        print(f"  |  {len(errors)} errors: {', '.join(n for n,_ in errors)}", end="")
    print()

    sys.exit(0 if not failed and not errors else 1)


if __name__ == "__main__":
    main()
