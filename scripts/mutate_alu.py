#!/usr/bin/env python3
"""mutate_alu.py - does the UVM environment catch real bugs?   (checking the checks)

    mutate_alu.py [--only A01 ...] [--report results/mutants.txt]

Each mutant is a one-line edit of Design/alu.v. It is run through the complete UVM testbench (WIDTH = 8, exhaustive sequence: every
opcode x every operand pair) with scripts/run_uvm.sh. A mutant is KILLED when the scoreboard reports failures or the UVM report has
errors; it SURVIVES otherwise. Survivors are not hidden: each one carries the reason (equivalent mutant, or a gap of the environment).
"""
import argparse
import os
import re
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MUTANTS = [
    ("A01", "SUB without the carry-in (a - b computed as a + ~b)", "{1'b0, operand2} + subtract;", "{1'b0, operand2};", "killed"),
    ("A02", "result LSB forced to 0 for ADD/SUB", "result_comb = adder_out[WIDTH-1:0];", "result_comb = {adder_out[WIDTH-1:1], 1'b0};", "killed"),
    ("A03", "ADD/SUB carry taken from the wrong adder bit", "carry_comb  = adder_out[WIDTH];", "carry_comb  = adder_out[WIDTH-1];", "killed"),
    ("A04", "AND implemented as OR", "result_comb = num1 & num2;", "result_comb = num1 | num2;", "killed"),
    ("A05", "XOR implemented as AND", "result_comb = num1 ^ num2;", "result_comb = num1 & num2;", "killed"),
    ("A06", "reserved opcodes return num1 instead of 0", "default: begin result_comb = {WIDTH{1'b0}}; carry_comb = 1'b0; end", "default: begin result_comb = num1; carry_comb = 1'b0; end", "gap"),
    ("A07", "subtract also asserted for OR (the adder is not used by OR)", "wire subtract = (opcode == OP_SUB);", "wire subtract = (opcode == OP_SUB) || (opcode == OP_OR);", "equivalent"),
    ("A08", "result register resets to all-ones instead of 0", "            result    <= {WIDTH{1'b0}};", "            result    <= {WIDTH{1'b1}};", "gap"),
    ("A09", "carry_out register stuck at 0", "carry_out <= carry_comb;", "carry_out <= 1'b0;", "killed"),
    ("A10", "SUB carry has the wrong sense", "carry_comb  = adder_out[WIDTH];", "carry_comb  = adder_out[WIDTH] ^ subtract;", "killed"),
    ("A11", "OR implemented as XOR", "result_comb = num1 | num2;", "result_comb = num1 ^ num2;", "killed"),
    ("A12", "XOR implemented as OR", "result_comb = num1 ^ num2;", "result_comb = num1 | num2;", "killed"),
    ("A13", "operand 2 not inverted for SUB", "wire [WIDTH-1:0] operand2  = num2 ^ {WIDTH{subtract}};", "wire [WIDTH-1:0] operand2  = num2;", "killed"),
    ("A14", "carry_out register resets to 1", "            carry_out <= 1'b0;", "            carry_out <= 1'b1;", "gap"),
]


def run(mid, desc, old, new, out, ext=False):
    wd = os.path.join(ROOT, "build", "mut", mid)
    shutil.rmtree(wd, ignore_errors=True)
    os.makedirs(wd)
    src = open(os.path.join(ROOT, "Design", "alu.v")).read()
    if src.count(old) != 1:
        return None, "old text occurs %d times" % src.count(old)
    dut = os.path.join(wd, "alu.v")
    open(dut, "w").write(src.replace(old, new))
    cmd = [os.path.join(ROOT, "scripts", "run_uvm.sh"), wd, "--dut", dut]
    if ext:
        cmd += ["--ext", os.path.join(ROOT, "ext", "uvm_ext.sv"), "--plus", "+uvm_set_type_override=corner_case_seq,corner_case_seq_vl"]
    r = subprocess.run(cmd, capture_output=True, text=True)
    log = os.path.join(wd, "run.log")
    if not os.path.exists(log) or "UVM Report Summary" not in open(log).read():
        return None, "run failed: " + (r.stdout + r.stderr)[-200:]
    t = open(log).read()
    m = re.search(r"Total=(\d+) Pass=(\d+) Fail=(\d+)", t)
    errs = int(re.search(r"UVM_ERROR :\s*(\d+)", t).group(1))
    return dict(total=int(m.group(1)), fail=int(m.group(3)), errors=errs), ""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", nargs="*", default=[])
    ap.add_argument("--with-ext", action="store_true", help="add ext/uvm_ext.sv: the corner-case extension that closes the A06 hole")
    ap.add_argument("--report", default=None)
    a = ap.parse_args()
    rows, problems = [], []
    for mid, desc, old, new, expect in MUTANTS:
        if a.only and mid not in a.only:
            continue
        res, err = run(mid, desc, old, new, None, a.with_ext)
        if res is None:
            rows.append("%s  ERROR     %s  (%s)" % (mid, desc, err))
            problems.append("%s: %s" % (mid, err))
            continue
        killed = res["fail"] > 0 or res["errors"] > 0
        if a.with_ext and mid == "A06":
            expect = "killed"
        verdict = "KILLED" if killed else "SURVIVED"
        rows.append("%s  %-9s %-62s scoreboard fail %6d of %d, UVM_ERROR %d   [expected: %s]" % (mid, verdict, desc, res["fail"], res["total"], res["errors"], expect))
        if killed != (expect == "killed"):
            problems.append("%s: expected %s, got %s" % (mid, expect, verdict))
    n_k = sum(1 for r in rows if " KILLED " in r)
    summary = ["mutants run: %d, killed %d, survived %d" % (len(rows), n_k, len(rows) - n_k),
               "environment: %s" % ("ORIGINAL sources + ext/uvm_ext.sv (corner-case extension)" if a.with_ext else "ORIGINAL sources, unmodified"),
               "survivors are annotated: A07 is an equivalent mutant (OR does not use the adder, so its output cannot change); A08 and A14 change only the",
               "reset value of a register, which this environment never samples (the monitor discards everything until one clock after reset is released): a gap, not an equivalent;",
               "A06 (reserved opcodes return num1) survives the original environment because corner_case_seq sends reserved opcodes only with zero operands: a stimulus gap, closed by the extension.",
               "PROBLEMS: %s" % ("; ".join(problems) if problems else "none (every outcome matched its expectation)"), ""]
    a.report = a.report or os.path.join(ROOT, "results", "mutants_ext.txt" if a.with_ext else "mutants.txt")
    os.makedirs(os.path.dirname(a.report), exist_ok=True)
    open(a.report, "w").write("\n".join(summary + rows) + "\n")
    print("\n".join(summary + rows))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
