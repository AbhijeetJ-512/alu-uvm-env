# 4-bit full adder: RTL design + UVM verification

## Purpose

A self-contained practice project pairing a small, structurally-built RTL
design with a complete, self-checking UVM environment. Built as a
follow-up to the AXI-DMA-Controller project's verification review, to
practice the class of code a UVM verification interview asks candidates
to write, and to demonstrate a scoreboard and coverage model that
actually check something (the AXI-DMA-Controller project's scoreboard
only logs; this one compares expected vs. actual and reports coverage).

Success criteria: a 4-bit ripple-carry adder verified with a UVM
testbench that exhaustively exercises all 512 input combinations,
self-checks every one against a computed expected result, and reports
functional coverage.

## Directory structure

```
4-Bit-Full-Adder-RTL-Design-and-UVM-Verification/
  Design/
    full_adder_1bit.v
    ripple_carry_adder_4bit.v
  Verification/
    interface.sv
    transaction.sv
    sequence.sv
    driver.sv
    monitor.sv
    coverage.sv
    scoreboard.sv
    agent.sv
    env.sv
    test.sv
    testbench.sv
  README.md
```

## RTL design

**`full_adder_1bit`** — combinational 1-bit full adder.
Ports: `input a, b, cin; output sum, cout;`
Behavior: `{cout, sum} = a + b + cin` (implemented structurally with
XOR/AND/OR gates, not a bare `assign` of the arithmetic expression, so
the module actually demonstrates gate-level full-adder logic).

**`ripple_carry_adder_4bit`** — structural composition.
Ports: `input [3:0] a, b; input cin; output [3:0] sum; output cout;`
Implementation: a `generate` loop instantiating four `full_adder_1bit`
instances, chaining `cout[i]` into `cin[i+1]`, matching the pattern
already used in the sibling `Full-Adder` project's `rippleCarryAdder`.
No parameterization beyond N=4 — YAGNI, this project is scoped to 4
bits specifically.

Both modules are purely combinational. No clock, no reset, no internal
state.

## Verification architecture

Component shape mirrors the AXI-DMA-Controller testbench (sequence →
sequencer → driver → DUT; DUT → monitor → scoreboard), with one
addition: a `coverage` component subscribed to the monitor's analysis
port alongside the scoreboard, so checking and coverage measurement are
separate components.

**`dma_if`-equivalent interface** (`adder_if`): bundles `clk`, `a[3:0]`,
`b[3:0]`, `cin`, `sum[3:0]`, `cout`, and a one-cycle `valid` strobe. The
DUT itself is combinational and needs no clock, but the testbench still
runs on a clock for a conventional drive-then-sample handshake — and
the `valid` strobe is what tells the monitor exactly when to sample,
rather than sampling on every clock edge (which would otherwise send
duplicate transactions for every idle cycle between driven stimuli).

**`transaction`**: `rand bit [3:0] a, b; rand bit cin;` for stimulus,
plus `bit [3:0] sum; bit cout;` populated by the monitor after sampling
the DUT's outputs. Constraint block left open (no illegal states exist
for an adder — every combination of `a`/`b`/`cin` is legal), which
itself is a useful contrast with the AXI-DMA-Controller's
`valid_transfer` constraint.

**`driver`**: pulls each item via `get_next_item`, drives `a`, `b`,
`cin` onto the interface, waits one clock edge for the combinational
result to settle, pulses `valid` high for exactly one clock edge, then
`item_done()`.

**`monitor`**: every clock edge, checks `vif.valid`; when high, samples
`a`, `b`, `cin`, `sum`, `cout` into a fresh `transaction` and broadcasts
it via `uvm_analysis_port#(transaction)`. Idle cycles (`valid` low)
produce no transaction.

**`scoreboard`**: `uvm_analysis_imp` receiving each transaction; computes
`expected = tr.a + tr.b + tr.cin` and compares
`expected[3:0] == tr.sum` and `expected[4] == tr.cout`. Maintains
pass/fail counters and reports a summary in `report_phase`
(`` `uvm_error `` on mismatch, includes the offending `a`/`b`/`cin`).

**`coverage`**: `uvm_subscriber#(transaction)` (or an analysis-port
receiver) sampling a `covergroup` that cross-covers `a`, `b`, `cin`
(full 4x4x1-bit cross = 512 bins), plus named single bins for the
corner cases (`all_zero`, `all_ones`, `max_carry_chain`). Reports final
coverage percentage in `report_phase`.

**`agent`**: bundles driver + sequencer + monitor, active/passive gated
by config, same pattern as the AXI-DMA-Controller's `agent`.

**`env`**: instantiates agent + scoreboard + coverage, wires
monitor → scoreboard and monitor → coverage.

**Sequences**:
- `exhaustive_seq` — iterates all 512 combinations of `a` (0-15),
  `b` (0-15), `cin` (0-1) directly (not via `randomize()` — a plain
  loop), guaranteeing 100% coverage regardless of random seed.
- `corner_case_seq` — a short directed sequence: `0+0+0`,
  `15+15+1` (max carry-out), `15+0+1`, `0+15+1` (carry-propagate
  chain).
- `random_seq` — a small constrained-random sequence (e.g. 20 items)
  using `randomize()`, included specifically to demonstrate
  constrained-random usage even though it's redundant with the
  exhaustive sequence for coverage purposes.

**`test`**: builds the env, runs `corner_case_seq`, then `random_seq`,
then `exhaustive_seq`, on the agent's sequencer, then checks final
coverage and pass/fail counts before dropping the objection.

**`testbench`** (`adder_tb_top`): generates `clk`, instantiates the DUT,
binds the interface via `uvm_config_db`, calls `run_test("test")`. No
reset signal needed (DUT is combinational and stateless).

## Error handling

Not really applicable — this is a combinational, stateless DUT with no
illegal input space. The "error handling" in this project is entirely
in the scoreboard: every mismatch is flagged via `` `uvm_error `` with
the specific inputs that caused it, and the final report fails loudly
(non-zero mismatch count) rather than silently passing.

## Testing

The UVM environment is the test. There's no separate test suite for the
testbench code itself — running `exhaustive_seq` and getting zero
scoreboard mismatches with 100% coverage is the correctness signal for
both the RTL and the verification environment together.

## Out of scope

- Simulator run scripts / Makefile (which simulator is available wasn't
  specified; the source is simulator-agnostic Verilog/SystemVerilog +
  UVM 1.2, matching the AXI-DMA-Controller project's precedent of
  shipping source only).
- SVA assertions, UVM register layer (RAL), virtual sequencer — none
  are needed for a single-agent, single-DUT, purely combinational
  design.
- The existing `Full-Adder` project's synthesis/PnR flow — untouched,
  unrelated.
- Parameterizing beyond N=4 bits.
