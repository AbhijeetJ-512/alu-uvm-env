# Third-party files

The MIT license in `LICENSE` covers my own work in this repository. Nothing from other projects is copied into it.

## Fetched, not included

`scripts/setup_toolchain.sh` builds Verilator 5.052 from source and fetches Antmicro's `uvm-verilator` (the Accellera UVM library with the changes
Verilator needs) into a toolchain folder outside this repository. Each keeps its own license: Verilator is LGPL-3.0 or Artistic-2.0, `uvm-verilator`
and the Accellera UVM library are Apache-2.0. `scripts/dpi_wrappers/` only includes their headers.
