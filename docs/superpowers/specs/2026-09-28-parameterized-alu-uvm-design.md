# Parameterized ALU: RTL design + UVM verification

## Purpose

A practice project pairing a small, parameterized RTL design with a
complete, self-checking UVM environment: a fixed-latency ALU that
accepts one instruction (operation + two operands) per clock cycle and
produces the corresponding result on the next clock cycle, supporting
addition, subtraction, AND, OR, and XOR, with the operand/result width
configurable for testing at different bit widths.

Success criteria: a parameterized ALU verified with a UVM testbench
that self-checks every instruction's result against a computed expected
value, correctly reconstructs which result belongs to which instruction
despite the 1-cycle pipeline delay, and reports functional coverage
that scales sensibly regardless of the configured width.

## Directory structure

```
Parameterized-ALU-RTL-Design-and-UVM-Verification/
  Design/
    alu.v
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

**`alu`** — single module, parameterized.

```
module alu #(parameter WIDTH = 8) (
  input  wire                  clk,
  input  wire                  rst_n,
  input  wire [2:0]            opcode,
  input  wire [WIDTH-1:0]      num1,
  input  wire [WIDTH-1:0]      num2,
  output reg  [WIDTH-1:0]      result,
  output reg                   carry_out
);
```

**Opcode encoding** (3 bits, 5 used, 3 reserved):

| opcode | operation |
|--------|-----------|
| `3'b000` | ADD |
| `3'b001` | SUB |
| `3'b010` | AND |
| `3'b011` | OR |
| `3'b100` | XOR |
| `3'b101`-`3'b111` | reserved — `result`/`carry_out` drive to 0 |

**Implementation approach**: ADD and SUB share one adder, the standard
technique of conditionally inverting the second operand and injecting
the inversion as carry-in (`num2 ^ {WIDTH{subtract}}` with
`cin = subtract`), rather than writing separate `+`/`-` logic paths.
`carry_out` for ADD/SUB is the adder's true carry-out bit — for SUB
this follows the conventional "carry set = no borrow" polarity
(`carry_out = 1` means `num1 >= num2`). AND/OR/XOR drive `carry_out` to
0 (no carry concept for logical ops).

**Timing**: fixed 1-cycle latency, always-accepting, no handshake.
`opcode`/`num1`/`num2` are combinationally decoded every cycle; the
computed `result`/`carry_out` are registered on the same `posedge clk`
that latches them — so the result for the instruction present on the
inputs during cycle N is visible on the outputs during cycle N+1, and a
new instruction can be presented every single cycle with no stalls.
`rst_n` clears `result`/`carry_out` to 0 and is otherwise not needed
(no internal pipeline state beyond the one output register).

Width is a true compile-time parameter — "testing different sizes"
means re-elaborating the design with a different `WIDTH`, not a
runtime-configurable bus.

## Verification architecture

Component shape: sequence → sequencer → driver → DUT; DUT → monitor →
scoreboard, plus a `coverage` component subscribed to the monitor's
analysis port alongside the scoreboard, so checking and coverage
measurement stay in separate components.

**The one real wrinkle vs. a purely combinational DUT**: because the
result for an instruction only appears one cycle *after* that
instruction was driven, something has to re-pair "this result" with
"the instruction that produced it." That job belongs to the monitor,
not the scoreboard — the monitor holds the `opcode`/`num1`/`num2` it
saw last cycle in a one-cycle delay register, and each cycle pairs that
delayed instruction with the *current* cycle's `result`/`carry_out`
before broadcasting one complete, self-contained transaction. This
keeps the scoreboard itself stateless: it always receives a
transaction whose input fields and output fields already belong
together, so it just recomputes the expected result and compares — no
queue, no latency bookkeeping, in the scoreboard.

**`alu_if`**: parameterized on `WIDTH`, bundles `clk`, `rst_n`,
`opcode[2:0]`, `num1[WIDTH-1:0]`, `num2[WIDTH-1:0]`,
`result[WIDTH-1:0]`, `carry_out`.

**`transaction`**: `rand bit [2:0] opcode; rand bit [WIDTH-1:0] num1,
num2;` for stimulus, plus `bit [WIDTH-1:0] result; bit carry_out;`
populated by the monitor. `opcode` constrained to the 5 legal values —
the reserved encodings are exercised directly by `corner_case_seq`
instead (see Sequences), so no separate randomized path to them is
needed.

**`driver`**: drives a new instruction onto the interface every clock
edge; calls `item_done()` immediately after driving (not after waiting
for the result), so the sequencer can supply the next item on the very
next cycle — this is what makes back-to-back, one-instruction-per-cycle
driving possible.

**`monitor`**: every `posedge clk`, captures `opcode`/`num1`/`num2` into
a one-cycle delay register, and — starting from the second cycle after
reset (the first post-reset cycle has no prior instruction to pair
with) — packages the delayed instruction fields together with the
current cycle's `result`/`carry_out` into one `transaction` and
broadcasts it via `uvm_analysis_port#(transaction)`.

**`scoreboard`**: `uvm_analysis_imp` receiving each paired transaction;
recomputes the expected `result`/`carry_out` from `opcode`/`num1`/
`num2` in SystemVerilog (mirroring the RTL's op semantics, including
the same carry/borrow polarity) and compares against the transaction's
`result`/`carry_out`. Pass/fail counters, summary with `` `uvm_error ``
detail on mismatch in `report_phase`.

**`coverage`**: a `covergroup`, subscribed via the monitor's analysis
port, designed to scale with `WIDTH` rather than assuming a small
input space:
- `opcode` coverpoint — one bin per legal operation, plus a bin for
  the reserved encodings.
- `num1_class` / `num2_class` coverpoints — value-class bins expressed
  relative to `WIDTH` (`zero`, `max` i.e. `{WIDTH{1'b1}}`, `low` i.e.
  the bottom half of the range, `high` i.e. the top half), not exact
  values — this is what keeps the model meaningful at WIDTH=4 and at
  WIDTH=32 alike.
- a cross of `opcode` × `num1_class` × `num2_class` (bounded regardless
  of `WIDTH`: 5 × 4 × 4 = 80 bins).
- a `carry_out` coverpoint crossed with `opcode`, to make sure both the
  carry and no-carry cases are exercised for ADD and SUB specifically.

Reports final coverage percentage in `report_phase`.

**`agent`**: bundles driver + sequencer + monitor, active/passive gated
by config.

**`env`**: instantiates agent + scoreboard + coverage, wires
monitor → scoreboard and monitor → coverage.

**Sequences**:
- `exhaustive_seq` — iterates every `{opcode, num1, num2}` combination
  directly. Only practical for small default widths (documented as
  intended for `WIDTH <= 8`; at `WIDTH = 8` that's 5 × 256 × 256 ≈
  327,680 instructions, still fast for a pure combinational compute —
  at `WIDTH = 32` the space is astronomically large and this sequence
  is not meant to be run).
- `corner_case_seq` — a short directed sequence, written generically
  against `WIDTH` (`{WIDTH{1'b0}}`, `{WIDTH{1'b1}}`, alternating-bit
  patterns) so it works unchanged at any configured width: zero op
  zero, max op max (carry/overflow on ADD), max SUB min and min SUB max
  (both borrow directions), one operand at each value class crossed
  with each opcode, and each of the three reserved opcodes issued once
  to confirm the documented `result = 0, carry_out = 0` default.
- `random_seq` — constrained-random, run in a loop that checks the
  coverage component's `get_coverage()` after each batch and stops once
  it plateaus or a safety-cap transaction count is hit (coverage-driven
  termination, not a fixed repeat count) — this is the sequence
  intended for larger widths where exhaustive coverage isn't feasible.

**`test`**: builds the env, runs `corner_case_seq`, then chooses the
second sequence with a plain `if (WIDTH <= 8)` check on the parameter
(no separate test classes or plusargs needed) — `exhaustive_seq` below
the threshold, `random_seq` above it — then checks final coverage and
pass/fail counts before dropping the objection.

**`testbench`** (`alu_tb_top`): generates `clk`, pulses `rst_n` low at
the start, instantiates the DUT with a chosen `WIDTH`, binds the
interface via `uvm_config_db`, calls `run_test("test")`.

## Error handling

The DUT has no illegal input space (every opcode/operand combination
either computes a defined result or falls into the documented reserved-
opcode default) — "error handling" here is entirely in the scoreboard:
every mismatch is flagged via `` `uvm_error `` naming the specific
opcode/operands that produced it, and the final report fails loudly
(non-zero mismatch count) rather than passing silently.

## Testing

The UVM environment is the test. Running the appropriate sequence set
for the configured `WIDTH` and getting zero scoreboard mismatches with
the coverage goal met is the correctness signal for the RTL and the
verification environment together.

## Out of scope

- Simulator run scripts / Makefile (simulator-agnostic Verilog/
  SystemVerilog + UVM 1.2 source only).
- SVA assertions, UVM register layer (RAL), virtual sequencer — not
  needed for a single-agent, single-DUT design.
- Multi-cycle/variable-latency operations, pipelining beyond the single
  1-cycle result register, and backpressure/handshake signals.
- Runtime-reconfigurable width (width is compile-time only).
