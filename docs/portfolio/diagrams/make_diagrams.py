#!/usr/bin/env python3
"""alu_uvm_env diagrams (dgm.py). Run: python3 docs/portfolio/diagrams/make_diagrams.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)   # dgm.py sits next to this file
from dgm import Diagram  # noqa: E402


def architecture():
    d = Diagram("UVM environment for the parameterised ALU - architecture", 1330, 700)
    d.legend = ("data", "ctrl")
    d.legend_pos = (1120, 12)
    d.group("ga", 285, 70, 590, 335, "agent  (is_active = UVM_ACTIVE, from alu_config)", label_pos="bottom")
    d.box("seq", 20, 100, 230, 170, "Sequences", "block", sub="corner_case_seq\nexhaustive_seq (WIDTH <= 8)\nrandom_seq (WIDTH > 8)\n(uvm_sequence#(transaction))", size=11)
    d.box("sqr", 305, 100, 250, 65, "sequencer", "block", sub="uvm_sequencer#(transaction)", size=11)
    d.box("drv", 305, 205, 250, 85, "driver", "accent", sub="get_next_item, drive opcode,\nnum1, num2 on the vif, item_done", size=11)
    d.box("mon", 605, 205, 250, 110, "monitor", "accent", sub="re-pairs each result with the\ninstruction driven one cycle\nearlier (DUT latency = 1)", size=11)
    d.box("if", 305, 440, 550, 55, "alu_if  (virtual interface)", "io", sub="clk, rst_n, opcode, num1, num2, result, carry_out", size=11)
    d.box("dut", 305, 545, 550, 110, "DUT: alu  (WIDTH parameter)", "fsm", sub="ADD SUB AND OR XOR; reserved opcodes -> 0;\nregistered result and carry, one cycle of latency", size=11)
    d.box("top", 20, 440, 250, 215, "testbench top  (alu_tb_top)", "io", sub="generates clk and reset,\ninstantiates DUT and interface,\nconfig_db::set(vif),\nrun_test(\"test\")", size=11)
    d.box("sb", 930, 100, 380, 120, "scoreboard", "ctrl", sub="uvm_analysis_imp\nindependent model: native + and -,\ncarry = (a >= b) for SUB; counts pass / fail", size=11)
    d.box("cov", 930, 260, 380, 120, "coverage  (uvm_subscriber)", "mem", sub="covergroup: op_cp, num1_cp, num2_cp, carry_cp,\nop x operands, op x carry\nvalue classes zero / low / high / max", size=11)
    d.arrow("a1", "seq", "sqr", sside="r", dside="l", sf=0.3, df=0.5, label="start(seqr)", lpos=(268, 110))
    d.arrow("a2", "sqr", "drv", sside="b", dside="t", label="seq_item_port", lpos=(430, 187))
    d.arrow("a3", "drv", "if", sside="b", dside="t", sf=0.3, df=0.14, label="pin-level drive", lpos=(378, 372))
    d.arrow("a4", "if", "mon", sside="t", dside="b", sf=0.86, df=0.5, label="sampled signals", lpos=(790, 380))
    d.arrow("a5", "if", "dut", sside="b", dside="t", both=True, label="signals", lpos=(600, 520))
    d.arrow("c1", "mon", "sb", kind="ctrl", sside="r", dside="l", sf=0.25, df=0.5, label="ap.write(tr)", lpos=(890, 158))
    d.arrow("c2", "mon", "cov", kind="ctrl", sside="r", dside="l", sf=0.7, df=0.5, label="ap.write(tr)", lpos=(890, 298))
    d.text("n", 930, 410, "The monitor publishes each complete\ntransaction through ONE analysis port;\nthe scoreboard checks it, the coverage\nsubscriber samples it.", 11, italic=True)
    d.text("n2", 20, 675, "Sequences generate transactions, the driver applies them through the virtual interface, the monitor observes inputs and outputs, and the environment checks and measures what it observed.", 10, italic=True)
    return d


def run_flow():
    d = Diagram("UVM run flow of the ALU test (phases and sequences)", 1100, 1050)
    d.legend = ("flow",)
    d.legend_pos = (900, 12)
    C, W = 330, 300
    cx = C + W / 2
    d.box("b", C, 55, W, 60, "build_phase", "proc", sub="create env, agent, driver, monitor,\nscoreboard, coverage; get vif from config_db", size=11)
    d.box("c", C, 145, W, 55, "connect_phase", "proc", sub="monitor ap -> scoreboard, coverage;\ndriver <-> sequencer", size=11)
    d.box("r", C, 230, W, 50, "run_phase: raise objection", "proc", sub="reset released after 20 ns", size=12)
    d.box("s1", C, 310, W, 58, "corner_case_seq", "proc", sub="zero / max / low / high operands for each opcode,\nSUB extremes, reserved opcodes 5, 6, 7", size=11)
    d.box("dw", C, 400, W, 78, "WIDTH <= 8 ?", "dec", size=12)
    d.box("ex", 40, 420, 230, 70, "exhaustive_seq", "proc", sub="5 opcodes x 2^W x 2^W\n(327,680 items at W = 8)", size=11)
    d.box("rn", 690, 420, 330, 70, "random_seq", "proc", sub="dist-weighted operands per value class,\nstops at 100 % coverage or 20,000 items", size=11)
    d.box("dr", C, 530, W, 65, "drain the 1-cycle DUT pipeline", "proc", sub="2 clocks + negedge so the last\ntwo results reach scoreboard and coverage", size=11)
    d.box("ck", C, 625, W, 90, "checks", "dec", sub="scoreboard checked > 0 ?\nfail_count == 0 ?  coverage >= 95 % ?", size=11)
    d.box("er", 690, 640, 330, 62, "UVM_ERROR / UVM_WARNING", "bad", sub="reported in the final UVM report", size=11)
    d.box("dn", C, 745, W, 50, "drop objection", "proc", size=12)
    d.box("rp", C, 825, W, 70, "report_phase / UVM report summary", "term", sub="counts by severity; scoreboard Total / Pass / Fail;\ncoverage %", size=11)
    for a, b, lab in [("b", "c", ""), ("c", "r", ""), ("r", "s1", ""), ("s1", "dw", ""), ("dr", "ck", ""), ("ck", "dn", "all good"), ("dn", "rp", "")]:
        d.arrow("m_" + a, a, b, kind="flow", sside="b", dside="t", label=lab, lpos=(cx + 55, (d.node(a).y + d.node(a).h + d.node(b).y) / 2) if lab else None)
    d.arrow("w1", "dw", "ex", kind="flow", sside="l", dside="r", label="yes", lpos=(305, 432))
    d.arrow("w2", "dw", "rn", kind="flow", sside="r", dside="l", label="no", lpos=(655, 432))
    d.arrow("w3", "ex", "dr", kind="flow", sside="b", dside="l", sf=0.5, df=0.5, via=[(155, 562)])
    d.arrow("w4", "rn", "dr", kind="flow", sside="b", dside="r", sf=0.5, df=0.5, via=[(855, 562)])
    d.arrow("w5", "ck", "er", kind="flow", sside="r", dside="l", label="a check fails", lpos=(655, 662))
    d.arrow("w6", "er", "dn", kind="flow", sside="b", dside="r", sf=0.5, df=0.5, via=[(855, 770)])
    d.text("n", 20, 930, "Verilator 5.052 compiles the covergroup and records every bin's hits in coverage.dat, but cg.get_coverage() returns 0.00 % and ignore_bins is not applied; the functional coverage reported in this project is computed\nfrom coverage.dat by scripts/cov_uvm.py. Verilator's constraint solver also rejects the dist-weighted randomize() of random_seq; ext/uvm_ext.sv supplies a procedural equivalent selected by a UVM factory override.", 10, italic=True)
    return d


def toolchain():
    d = Diagram("Running UVM on open-source tools: the toolchain used here", 1300, 430)
    d.legend = ()
    xs = [20, 275, 530, 785, 1040]
    items = [("UVM testbench", "Verification/*.sv\n(unmodified)", "block"), ("uvm-verilator", "Accellera UVM 1800.2-2017\nwith Verilator patches", "mem"), ("DPI shim", "3 wrapper .cc files:\nextern \"C\" + uvm_dpi.h;\nHDL backdoor off", "ctrl"),
             ("Verilator 5.052", "--binary --timing --vpi\n--public-flat-rw --coverage-user", "accent"), ("simulator + coverage.dat", "UVM report, scoreboard counts,\ncovergroup bin hits", "io")]
    for i, (n, s, k) in enumerate(items):
        d.box("t%d" % i, xs[i], 100, 235, 130, n, k, sub=s, size=12)
        if i:
            d.arrow("f%d" % i, "t%d" % (i - 1), "t%d" % i, kind="data")
    d.box("x1", 275, 290, 480, 90, "scripts/setup_toolchain.sh", "io", sub="builds Verilator v5.052 from source and fetches uvm-verilator", size=12)
    d.box("x2", 785, 290, 490, 90, "scripts/cov_uvm.py, mutate_alu.py", "io", sub="functional coverage from coverage.dat; injected-bug campaign through the full UVM test", size=12)
    d.arrow("g1", "x1", "t3", kind="ctrl", sside="t", dside="b", sf=0.75, df=0.3)
    d.arrow("g2", "t4", "x2", kind="ctrl", sside="b", dside="t", sf=0.5, df=0.5)
    return d


if __name__ == "__main__":
    for n, f in (("alu_uvm_architecture", architecture), ("alu_uvm_flowchart", run_flow), ("alu_uvm_toolchain", toolchain)):
        print(n, "overflow:", f().export_all(HERE, n))
