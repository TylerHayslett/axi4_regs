# AXI4_REGS

A small toolkit for defining, editing, and generating fully AXI4-compliant
memory-mapped register slaves. Register layouts are described in plain-text
CSV files and consumed by a cross-platform editor that generates RTL
(SystemVerilog and VHDL) and software-side artifacts (C headers, UVM RAL,
etc.).

See [docs/AXI4_REGS_spec.md](docs/AXI4_REGS_spec.md) for the full
specification and [docs/AXI4_REGS_tool_goals.txt](docs/AXI4_REGS_tool_goals.txt)
for the original goals.

## Repository Layout

```
axi4_regs/
├── README.md
├── reg_src.csv                  # Example register definition file
├── docs/
│   ├── AXI4_REGS_spec.md
│   └── AXI4_REGS_tool_goals.txt
├── hdl/
│   ├── axi4_regs_slave.sv       # AXI4 (full) slave, SystemVerilog
│   ├── axi4_regs_slave.vhd      # AXI4 (full) slave, VHDL
│   ├── axi4_lite_regs_slave.sv  # AXI4-Lite slave, SystemVerilog
│   └── axi4_lite_regs_slave.vhd # AXI4-Lite slave, VHDL
├── python_gui/
│   ├── reg_gui.py               # PyQt6 register editor / generator launcher
│   ├── parse_reg_struct.py      # CSV → DataFrame helpers
│   ├── write_dot_h.py           # C/C++ header generator
│   ├── write_sys_verilog.py     # SystemVerilog generator
│   ├── write_uvm_ral.py         # UVM RAL generator
│   ├── write_vhdl.py            # VHDL generator
│   └── axi4_regs_testing.mpf    # ModelSim/Questa project file
└── test_bench/
    ├── tb_axi4_regs_slave_sv.sv # SV-only testbench (SV DUTs)
    ├── tb_axi4_regs_slave_vhd.sv# Mixed-language testbench (VHDL DUTs)
    └── run_sim.tcl              # Simulator run script
```

## Components

### HDL Slaves (`hdl/`)

Four interchangeable slave implementations:

| File                       | Protocol   | Language       |
| -------------------------- | ---------- | -------------- |
| `axi4_regs_slave.sv`       | AXI4 full  | SystemVerilog  |
| `axi4_regs_slave.vhd`      | AXI4 full  | VHDL           |
| `axi4_lite_regs_slave.sv`  | AXI4-Lite  | SystemVerilog  |
| `axi4_lite_regs_slave.vhd` | AXI4-Lite  | VHDL           |

The full AXI4 slaves implement true burst support (`INCR`, `FIXED`, `WRAP`)
with per-beat address advancement. The AXI4-Lite slaves implement
single-beat read/write only (per the AXI4-Lite spec).

All four slaves route the bus address/data to an external user hook so
that the actual register decoding lives outside the bus FSM:

- **SystemVerilog**: `axi4_regs_user_pkg::reg_access(addr, write_en, wstrb, wdata, rdata)`
  (and `axi4_lite_regs_user_pkg::reg_access` for the Lite variant).
- **VHDL**: `axi4_regs_user_pkg.reg_access(...)` procedure
  (and `axi4_lite_regs_user_pkg.reg_access` for the Lite variant).

Replace the package body in your project with code generated from your
register CSV (or hand-written) to implement real register behavior. Both
the included stubs drop writes and return zero on reads.

BRESP/RRESP are always returned as `OKAY` (`2'b00`).

#### Mixed-language naming

To avoid name collisions when both VHDL and SystemVerilog implementations
are elaborated together, the VHDL entities are named with a `_vhd` suffix
(`axi4_regs_slave_vhd`, `axi4_lite_regs_slave_vhd`).

### Python GUI (`python_gui/`)

A cross-platform PyQt6 editor for the register CSV format with a one-click
"Generate" action that invokes each registered output backend.

Run it with:

```bash
cd python_gui
python3 reg_gui.py
```

Buttons:

- **Load CSV** / **Save CSV** — read/write a register definition file.
- **Add Row** / **Delete Row** — edit the table relative to the current
  selection.
- **Generate** — call `write_rows_to_file(df)` on each output module
  (`write_dot_h`, `write_sys_verilog`, `write_uvm_ral`, `write_vhdl`).

Empty rows are trimmed automatically on save.

### CSV Format

The example register file is at [reg_src.csv](reg_src.csv). One register
per row with these columns:

| Column          | Description                                                 |
| --------------- | ----------------------------------------------------------- |
| Register Name   | Identifier; supports array notation `name[array:size]`.     |
| Size (bits)     | Width of the field in bits.                                 |
| R/W/RW/etc.     | Access type (`R`, `W`, `RW`, `RO`, `COR`, ...).             |
| Type (string)   | User-defined category string.                               |
| Description     | Free-text description; `\n` is preserved through save/load. |

### Testbenches (`test_bench/`)

Two SystemVerilog testbenches share a small embedded master BFM and run
the same set of stimulus sequences:

- `tb_axi4_regs_slave_sv.sv` — instantiates the SystemVerilog DUTs only;
  pure SV elaboration.
- `tb_axi4_regs_slave_vhd.sv` — instantiates the VHDL DUTs (under their
  `_vhd` aliased names); requires mixed-language elaboration.

Each testbench exercises:

1. Single-beat write/read at `0x0000_0000`
2. Single-beat write/read at `0x0000_0010`
3. Byte-strobed write at `0x0000_0020`
4. Back-to-back single-beat reads at `0x0000_0030` / `0x0000_0034`
5. 4-beat INCR burst read at `0x0000_0040` (full-AXI only;
   AXI4-Lite has no bursts)

A run script is provided in [test_bench/run_sim.tcl](test_bench/run_sim.tcl).
For ModelSim/Questa it can be launched with the project file in
[python_gui/axi4_regs_testing.mpf](python_gui/axi4_regs_testing.mpf).

## Quick Start

1. Edit your registers:
   ```bash
   cd python_gui
   python3 reg_gui.py
   ```
   Load `../reg_src.csv`, edit, then **Save CSV** and click **Generate**.
2. Drop the generated user package body alongside the slave of your
   choice from `hdl/` into your project.
3. Wire the slave's AXI ports to your interconnect.
4. Run the testbenches in your simulator to sanity-check the bus.

## Status / Roadmap

Implemented:

- AXI4 full and AXI4-Lite slaves (SV + VHDL).
- True burst support (`INCR`/`FIXED`/`WRAP`) on the full-AXI slaves.
- PyQt6 register editor with multi-line `Description` support.
- Generator scaffolding for `.h`, SystemVerilog, VHDL, UVM RAL.
- Side-by-side testbenches for both languages.

Planned (see [docs/AXI4_REGS_spec.md](docs/AXI4_REGS_spec.md)):

- Filling in the SystemVerilog/VHDL/UVM RAL/`.h` generator bodies to
  emit real register decoding from `reg_src.csv`.
- Xilinx IP Integrator packaging scripts.
- TOML and other plain-data exports.
- Native register support for arrays, reset values, read-only,
  clear-on-read, and decoupled read/write fields.

## License

TBD.
