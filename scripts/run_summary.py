#!/usr/bin/env python3
"""run_summary.py - condense UVM run logs into results/uvm_runs.txt (the figures are read from the logs, not typed).

usage: run_summary.py LABEL=build/dir/run.log [LABEL=...]  > results/uvm_runs.txt
Also copies each log (the 3.5 MB original-sequence log is cut to its first 60 and last 60 lines) into results/logs/.
"""
import os, re, shutil, sys

def grab(pat, text, default="n/a"):
    m = re.search(pat, text)
    return m.group(1) if m else default

rows = []
os.makedirs("results/logs", exist_ok=True)
for arg in sys.argv[1:]:
    label, path = arg.split("=", 1)
    text = open(path, errors="replace").read()
    lines = text.splitlines()
    dst = f"results/logs/{label}.log"
    with open(dst, "w") as f:
        if len(lines) > 400:
            f.write("\n".join(lines[:60]) + f"\n... [{len(lines) - 120} lines cut: repeated UVM_ERROR lines] ...\n" + "\n".join(lines[-60:]) + "\n")
        else:
            f.write(text)
    rows.append(dict(
        label=label,
        width=grab(r"=== starting, WIDTH=(\d+)", text),
        total=grab(r"Total=(\d+) Pass=\d+ Fail=\d+", text),
        passed=grab(r"Total=\d+ Pass=(\d+) Fail=\d+", text),
        failed=grab(r"Total=\d+ Pass=\d+ Fail=(\d+)", text),
        err=grab(r"UVM_ERROR\s*:\s*(\d+)", text),
        fatal=grab(r"UVM_FATAL\s*:\s*(\d+)", text),
        warn=grab(r"UVM_WARNING\s*:\s*(\d+)", text),
        wall=grab(r"walltime ([\d.]+) s", text),
        ver=grab(r"Verilator ([\d.]+ \d{4}-\d\d-\d\d)", text),
        seq="random_seq_vl" if "RANDOM_SEQ_VL" in text else ("random_seq (original)" if "RANDOM_SEQ]" in text else "exhaustive_seq"),
    ))
hdr = f"{'run':<14}{'W':>3} {'sequence':<22}{'txns':>9}{'pass':>9}{'fail':>6}{'UVM_ERROR':>11}{'UVM_FATAL':>11}{'wall [s]':>10}"
print(hdr); print("-" * len(hdr))
for r in rows:
    print(f"{r['label']:<14}{r['width']:>3} {r['seq']:<22}{r['total']:>9}{r['passed']:>9}{r['failed']:>6}{r['err']:>11}{r['fatal']:>11}{r['wall']:>10}")
print(f"\nsimulator: Verilator {rows[0]['ver'] if rows else 'n/a'}, one thread, seed 1; 'txns' = scoreboard Total (corner_case_seq 25 + main sequence).")
print("note: the 'w16_original' run drives the unmodified random_seq; every one of its 20,000 randomize() calls fails on this simulator (UVM_ERROR),")
print("      which is why the run is reported but not counted as a verification result (see section G.4).")
