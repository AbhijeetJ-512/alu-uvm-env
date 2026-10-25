#!/usr/bin/env bash
# setup_toolchain.sh - build the two things this project needs that distributions do not package:
#   * Verilator v5.052 (a version new enough to elaborate the UVM class library and covergroups)
#   * github.com/antmicro/uvm-verilator (Accellera UVM, IEEE 1800.2-2017, with Verilator-specific patches)
# Result: <dir>/verilator-5.052 and <dir>/uvm-verilator.   Default <dir>: ../../_toolchain (override with UVM_TOOLCHAIN=...)
# Needs: git, a C++ compiler, make, autoconf, flex, bison, perl, python3. 
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
TC="${UVM_TOOLCHAIN:-$HERE/../../../_toolchain}"
mkdir -p "$TC"; TC="$(cd "$TC" && pwd)"
W="$(mktemp -d)"
trap 'rm -rf "$W"' EXIT
git clone --depth 1 --branch v5.052 https://github.com/verilator/verilator "$W/verilator"
git clone --depth 1 https://github.com/antmicro/uvm-verilator "$TC/uvm-verilator"
( cd "$W/verilator" && unset VERILATOR_ROOT && autoconf && ./configure && make -j"$(nproc)" )
mkdir -p "$TC/verilator-5.052"
cp -r "$W/verilator/bin" "$W/verilator/include" "$TC/verilator-5.052/"
rm -f "$TC/verilator-5.052/bin/"*_dbg
echo "toolchain ready in $TC"
VERILATOR_ROOT="$TC/verilator-5.052" "$TC/verilator-5.052/bin/verilator" --version
