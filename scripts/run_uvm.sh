#!/usr/bin/env bash
# run_uvm.sh - build the UVM testbench with Verilator 5.052 and run it.
#
#   run_uvm.sh <out-dir> [--width N] [--dut path/to/alu.v] [--seed S] [--ext file.sv] [--plus +arg]
#
# The testbench sources in Verification/ are used UNMODIFIED (WIDTH is changed in a copy of alu_pkg.sv when --width is given).
# Output in <out-dir>: build.log, run.log, coverage.dat, Valu_tb_top (the simulator). Exit status 0 only if the run finished
# and the UVM report shows no UVM_ERROR / UVM_FATAL.
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
TC="${UVM_TOOLCHAIN:-$HERE/../../_toolchain}"
export VERILATOR_ROOT="$TC/verilator-5.052"
VL="$VERILATOR_ROOT/bin/verilator"
UVM="$TC/uvm-verilator/src"
OUT="$1"; shift
WIDTH=""; DUT="$HERE/Design/alu.v"; SEED=1; EXT=""; PLUS=""
while [ $# -gt 0 ]; do
  case "$1" in
    --width) WIDTH="$2"; shift 2;;
    --dut)   DUT="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"; shift 2;;
    --seed)  SEED="$2"; shift 2;;
    --ext)   EXT="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"; shift 2;;     # extra SystemVerilog file compiled after the testbench
    --plus)  PLUS="$PLUS $2"; shift 2;;                                            # extra run-time plusarg
    *) echo "unknown option $1"; exit 2;;
  esac
done
mkdir -p "$OUT"; OUT="$(cd "$OUT" && pwd)"
# one shared copy per WIDTH, so the generated C++ for the (large) UVM classes is byte-identical between runs and ccache can reuse it
V="$HERE/build/_verification_w${WIDTH:-default}"
rm -rf "$V"; mkdir -p "$V"; cp -r "$HERE/Verification/." "$V/"
[ -n "$WIDTH" ] && sed -i "s/parameter int WIDTH = [0-9]*;/parameter int WIDTH = $WIDTH;/" "$V/alu_pkg.sv"
rm -rf "$OUT/obj"
D="$UVM/dpi"
( cd "$OUT" && "$VL" --binary --timing --vpi --public-flat-rw --coverage-user \
    -Wno-fatal -Wno-lint -Wno-style -Wno-UNOPTFLAT -Wno-WIDTH --Mdir obj -j "$(nproc)" \
    +define+UVM_HDL_NO_DPI -CFLAGS "-I$D -I$VERILATOR_ROOT/include/vltstd -w" \
    +incdir+"$UVM" +incdir+"$V" "$UVM/uvm_pkg.sv" \
    "$HERE/scripts/dpi_wrappers/w_common.cc" "$HERE/scripts/dpi_wrappers/w_svcmd_dpi.cc" "$HERE/scripts/dpi_wrappers/w_regex.cc" \
    "$DUT" "$V/testbench.sv" $EXT --top-module alu_tb_top > "$OUT/build.log" 2>&1 ) || { tail -30 "$OUT/build.log"; exit 1; }
( cd "$OUT/obj" && ./Valu_tb_top +UVM_NO_RELNOTES $PLUS +verilator+seed+"$SEED" +verilator+rand+reset+2 +verilator+coverage+file+"$OUT/coverage.dat" > "$OUT/run.log" 2>&1 ) || true
grep -q "UVM Report Summary" "$OUT/run.log" || { echo "run did not finish"; tail -20 "$OUT/run.log"; exit 1; }
if grep -E "^UVM_(ERROR|FATAL) :\s+[1-9]" "$OUT/run.log" >/dev/null; then echo "UVM errors reported"; exit 1; fi
grep -E "SCOREBOARD\] Total|UVM_(INFO|WARNING|ERROR|FATAL) :" "$OUT/run.log" | sed 's/^.*\[SCOREBOARD\]/[SCOREBOARD]/'
