#!/usr/bin/env python3
"""Parse nextpnr/yosys logs and print a compact coloured report."""

import re
import sys
import os

# ── ANSI helpers ────────────────────────────────────────────────────────────
RESET  = "\033[0m"
BOLD   = "\033[1m"
RED    = "\033[31m"
GREEN  = "\033[32m"
YELLOW = "\033[33m"
CYAN   = "\033[36m"
WHITE  = "\033[37m"
DIM    = "\033[2m"

def color(text, *codes):
    return "".join(codes) + str(text) + RESET

def pct_color(pct):
    if pct >= 85: return RED
    if pct >= 60: return YELLOW
    return GREEN

# ── bar ─────────────────────────────────────────────────────────────────────
BAR_WIDTH = 20
def bar(pct):
    filled = round(pct / 100 * BAR_WIDTH)
    c = pct_color(pct)
    return color("█" * filled, c) + color("░" * (BAR_WIDTH - filled), DIM)

# ── table helpers ────────────────────────────────────────────────────────────
def hline(widths, left="┌", mid="┬", right="┐", fill="─"):
    return left + mid.join(fill * (w + 2) for w in widths) + right

def row(cells, widths):
    parts = []
    for cell, w in zip(cells, widths):
        # strip ANSI for width calculation
        plain = re.sub(r'\033\[[^m]*m', '', cell)
        pad = w - len(plain)
        parts.append(" " + cell + " " * pad + " ")
    return "│" + "│".join(parts) + "│"

def print_table(title, headers, rows_data):
    all_rows = [headers] + rows_data
    # compute column widths from plain text
    widths = []
    for col in range(len(headers)):
        w = max(len(re.sub(r'\033\[[^m]*m', '', r[col])) for r in all_rows)
        widths.append(w)

    print()
    print(color(f"  {title}", BOLD, CYAN))
    print(hline(widths))
    print(row([color(h, BOLD, WHITE) for h in headers], widths))
    print(hline(widths, "├", "┼", "┤"))
    for r in rows_data:
        print(row(r, widths))
    print(hline(widths, "└", "┴", "┘"))

# ── parse pnr log ────────────────────────────────────────────────────────────
def parse_pnr_log(path):
    utilisation = {}
    fmax = {}
    critical_path_ns = None

    util_re   = re.compile(r'Device utilisation')
    res_re    = re.compile(r'Info:\s+([\w_]+):\s+(\d+)/\s*(\d+)')
    fmax_re   = re.compile(r"Max frequency for clock '([^']+)':\s+([\d.]+) MHz \((PASS|FAIL) at ([\d.]+) MHz\)")
    cp_re     = re.compile(r'Total path delay:\s+([\d.]+)\s*ns')

    inside_util = False
    with open(path) as f:
        for line in f:
            if util_re.search(line):
                inside_util = True
                continue
            if inside_util:
                m = res_re.search(line)
                if m:
                    utilisation[m.group(1)] = (int(m.group(2)), int(m.group(3)))
                elif line.strip() and 'Info:' not in line:
                    inside_util = False
            m = fmax_re.search(line)
            if m:
                fmax[m.group(1)] = {
                    'achieved': float(m.group(2)),
                    'status':   m.group(3),
                    'target':   float(m.group(4)),
                }
            m = cp_re.search(line)
            if m:
                critical_path_ns = float(m.group(1))

    return utilisation, fmax, critical_path_ns

# ── parse yosys json stat (optional) ─────────────────────────────────────────
def parse_yosys_stat(json_path):
    """Return dict of module → cell counts by running yosys stat."""
    try:
        import subprocess, json as _json
        result = subprocess.run(
            ["yosys", "-q", "-p", f"read_json {json_path}; stat -json"],
            capture_output=True, text=True, timeout=30
        )
        # yosys stat -json outputs JSON to stdout
        # Try to extract the JSON block
        out = result.stdout
        start = out.find('{')
        if start >= 0:
            data = _json.loads(out[start:])
            return data
    except Exception:
        pass
    return None

# ── main ─────────────────────────────────────────────────────────────────────
def main():
    build_dir = sys.argv[1] if len(sys.argv) > 1 else "build"
    proj      = sys.argv[2] if len(sys.argv) > 2 else "rv32e"

    pnr_log  = os.path.join(build_dir, f"{proj}_pnr.log")

    if not os.path.exists(pnr_log):
        print(color(f"Error: {pnr_log} not found. Run 'make pnr' first.", RED, BOLD))
        sys.exit(1)

    utilisation, fmax, cp_ns = parse_pnr_log(pnr_log)

    # ── Frequency ─────────────────────────────────────────────────────────
    freq_rows = []
    for clk, info in fmax.items():
        ach   = info['achieved']
        tgt   = info['target']
        st    = info['status']
        slack = ach - tgt
        st_col = color(f"✓ PASS (+{slack:.2f} MHz)", GREEN, BOLD) if st == "PASS" \
                 else color(f"✗ FAIL ({slack:.2f} MHz)", RED, BOLD)
        freq_rows.append([
            color(clk, CYAN),
            color(f"{tgt:.2f} MHz", WHITE),
            color(f"{ach:.2f} MHz", BOLD),
            st_col,
        ])

    print_table("Timing", ["Clock", "Target", "Achieved", "Status"], freq_rows)

    # ── Utilisation ───────────────────────────────────────────────────────
    DISPLAY = {
        "ICESTORM_LC":  "Logic Cells (LUT/FF)",
        "ICESTORM_RAM": "Block RAM",
        "SB_IO":        "I/O pads",
        "SB_GB":        "Global buffers",
        "ICESTORM_PLL": "PLL",
        "SB_SPRAM":     "SPRAM",
        "ICESTORM_DSP": "DSP",
    }

    util_rows = []
    for key, label in DISPLAY.items():
        if key not in utilisation:
            continue
        used, total = utilisation[key]
        pct = used / total * 100
        c   = pct_color(pct)
        util_rows.append([
            label,
            color(str(used),  BOLD),
            str(total),
            color(f"{pct:5.1f}%", c, BOLD),
            bar(pct),
        ])

    print_table("Device Utilisation (iCE40)", ["Resource", "Used", "Total", " %", ""], util_rows)

    # ── Critical path ─────────────────────────────────────────────────────
    if cp_ns:
        print(color("  Critical path: ", BOLD) + color(f"{cp_ns:.2f} ns", CYAN, BOLD))
        print()

if __name__ == "__main__":
    main()
