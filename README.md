# Parameterized ALU

A fixed-1-cycle-latency ALU (ADD/SUB/AND/OR/XOR) with a compile-time
parameterized operand/result width, verified with a self-checking UVM 1.2
testbench.

## Design

`Design/alu.v` accepts one instruction (`opcode`, `num1`, `num2`) every
clock cycle with no handshake, and produces the registered `result`/
`carry_out` for that instruction exactly one cycle later. ADD and SUB
share one adder (`num2` conditionally inverted, subtract fed in as
carry-in). Opcodes `3'b101`-`3'b111` are reserved and drive `result`/
`carry_out` to 0.

| opcode | operation |
|--------|-----------|
| `000`  | ADD |
| `001`  | SUB |
| `010`  | AND |
| `011`  | OR  |
| `100`  | XOR |

## Verification

`Verification/` is a UVM 1.2 environment: `sequence -> sequencer ->
driver -> DUT`, and `DUT -> monitor -> scoreboard` / `monitor ->
coverage`. Because the DUT's result lags its instruction by one cycle,
the monitor re-pairs each result with the instruction that produced it
before publishing a transaction, so the scoreboard can stay a stateless
comparator with an independently-derived expected-value model.

Coverage uses width-relative value-class bins (`zero`/`low`/`high`/
`max`) crossed with opcode, so it stays meaningful at any configured
`WIDTH` (set in `Verification/alu_pkg.sv`). `Verification/test.sv` runs
an exhaustive sequence for `WIDTH <= 8`, and a coverage-driven random
sequence above that.

## Running this

This environment was written and reviewed without execution — see
`docs/superpowers/specs/2026-09-28-parameterized-alu-uvm-design.md` for
why (no UVM-capable simulator was available in the environment this was
built in). It targets standard UVM 1.2 and needs a SystemVerilog
simulator with a UVM library (Questa, VCS, Xcelium, or a UVM-capable
Verilator build) — point it at `Verification/testbench.sv` as the
top-level module (`alu_tb_top`).
