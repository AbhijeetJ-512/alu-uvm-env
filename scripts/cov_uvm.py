#!/usr/bin/env python3
"""cov_uvm.py - functional coverage of the UVM covergroup, read from Verilator's coverage.dat.

    cov_uvm.py coverage.dat [--out summary.txt]

Verilator 5.052 compiles the covergroup in Verification/coverage.sv and records every bin's hit count in coverage.dat (page
v_covergroup), but (a) `cg.get_coverage()` returns 0.00 % and (b) `ignore_bins` is not applied: the bins that coverage.sv excludes still
appear, with zero hits. This script therefore computes the coverage itself, excluding exactly the bins the source declares ignored:

    op_x_operands : ignore_bins reserved_ops              = binsof(op_cp) intersect {[5:7]}        -> every bin whose op is reserved[i]
    op_x_carry    : ignore_bins logical_ops_and_reserved  = binsof(op_cp) intersect {[AND:XOR],[5:7]} -> every bin whose op is and/or/xor/reserved[i]

It prints both numbers: the raw count (what Verilator's data says) and the count with the declared ignore_bins removed.
"""
import argparse
import collections
import re
import sys


def parse(path):
    recs = []
    for line in open(path, "rb").read().decode("latin-1").splitlines():
        m = re.match(r"^C '(.*)' (\d+)$", line)
        if not m:
            continue
        f = {}
        for part in m.group(1).split("\x01")[1:]:
            k, _, v = part.partition("\x02")
            f[k] = v
        recs.append((f, int(m.group(2))))
    return recs


def ignored(point, name):
    if point == "op_x_operands":
        return name.startswith("reserved[")
    if point == "op_x_carry":
        return name.startswith(("b_and_", "b_or_", "b_xor_", "reserved["))
    return False


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dat")
    ap.add_argument("--out")
    a = ap.parse_args()
    bins = collections.defaultdict(list)
    for f, c in parse(a.dat):
        if not f.get("page", "").startswith("v_covergroup"):
            continue
        m = re.match(r"^[^.]*\.([^.]+)\.(.+)$", f["h"])
        if m:
            bins[m.group(1)].append((m.group(2), c))
    if not bins:
        print("cov_uvm: no covergroup records in %s" % a.dat)
        return 2
    lines = ["%-15s %6s %6s %8s %6s %6s" % ("coverpoint", "bins", "ignored", "counted", "hit", "zero")]
    tot_all = hit_all = ign_all = 0
    zero_names = []
    for p in sorted(bins):
        allb = bins[p]
        ign = [(n, c) for n, c in allb if ignored(p, n)]
        cnt = [(n, c) for n, c in allb if not ignored(p, n)]
        hit = sum(1 for _, c in cnt if c > 0)
        zero_names += ["%s.%s" % (p, n) for n, c in cnt if c == 0]
        lines.append("%-15s %6d %6d %8d %6d %6d" % (p, len(allb), len(ign), len(cnt), hit, len(cnt) - hit))
        tot_all += len(cnt)
        hit_all += hit
        ign_all += len(ign)
    raw_total = sum(len(v) for v in bins.values())
    raw_hit = sum(1 for v in bins.values() for _, c in v if c > 0)
    lines.append("")
    lines.append("raw (Verilator data as is, ignore_bins NOT applied) : %d / %d bins hit = %.2f %%" % (raw_hit, raw_total, 100.0 * raw_hit / raw_total))
    lines.append("with the declared ignore_bins removed (%d bins)      : %d / %d bins hit = %.2f %%" % (ign_all, hit_all, tot_all, 100.0 * hit_all / tot_all))
    lines.append("counted bins never hit: %s" % (", ".join(zero_names) if zero_names else "none"))
    text = "\n".join(lines)
    print(text)
    if a.out:
        open(a.out, "w").write(text + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
