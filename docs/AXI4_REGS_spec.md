# AXI4_REGS Tool Specification

## Overview

`AXI4_REGS` is a tool for defining, editing, and generating fully
AXI4-compliant memory-mapped register slaves. Register layouts are
described in plain-text value files and consumed by a cross-platform
editor that generates language-specific outputs (C/C++, SystemVerilog,
VHDL, TOML, etc.) along with packaging scripts for FPGA toolchains.

## Goals

- Provide a fully AXI4-compliant memory slave that maps addresses to
  discrete fields defined in a value file.
- Optionally support AXI4-Lite for lightweight peripherals.
- Allow multiple value files within a single project so a project can
  instantiate several independent `AXI_REGS` blocks.
- Use a plain-text format (CSV-style) for the value field description
  so files are diff-friendly and tool-agnostic.
- Ship a cross-platform editor that generates output value files in
  multiple target languages (C, C++, Verilog/SystemVerilog, VHDL, TOML,
  etc.).
- Default to byte-boundary separated fields for predictable software
  access patterns.
- Provide Xilinx IP Integrator packaging and support scripts.

## Register Capabilities

The register model shall support, at minimum, the following behaviors:

- Arrays of values (multiple instances of the same register layout).
- Default / reset values for each field.
- Read-only fields.
- Clear-on-read fields.
- Decoupled read / write fields (separate storage for the read path and
  the write path of the same address).

## Value File Format

Value files are plain text (CSV today) with one register per row.
Required columns:

| Field             | Description                                                   |
| ----------------- | ------------------------------------------------------------- |
| Register Name     | Identifier; supports array notation as `name[array:size]`.    |
| Size (bits)       | Width of the field in bits.                                   |
| R/W/RW/etc.       | Access type (e.g., `R`, `W`, `RW`, `RO`, `COR`, ...).         |
| Type (string)     | User-defined type / category string.                          |
| Description       | Free-text description of the field; multi-line allowed.       |

### Notes
- Multi-line descriptions are stored with `\n` escapes in the on-disk
  CSV and unescaped in the editor.
- Field ordering in the file determines address ordering.
- Byte-aligned packing is the default; explicit padding may be inferred
  by the generators.

## Editor Tool

A cross-platform GUI (`reg_gui.py`, PyQt6) shall provide:

- Loading and saving CSV value files.
- Tabular editing with multi-line support for the `Description` column.
- Adding and deleting rows relative to the current selection.
- A **Generate** action that invokes each registered output backend
  (`write_dot_h`, `write_sys_verilog`, `write_uvm_ral`, `write_vhdl`,
  ...) on the active register table.
- Trimming of fully blank rows on save.

## Output Generators

Each generator is a Python module exposing:

```python
def write_rows_to_file(df, filename=...):
    ...
```

Planned backends:

- `write_dot_h.py`     — C/C++ header (`.h`) with register offsets and
  field macros.
- `write_sys_verilog.py` — SystemVerilog package / register file.
- `write_uvm_ral.py`   — UVM Register Abstraction Layer model.
- `write_vhdl.py`      — VHDL package / register file.
- (Future) TOML and other plain-data exports.

## Packaging

- Provide TCL / scripted flows to package the generated RTL as a Xilinx
  IP Integrator IP, including bus interface inference for AXI4 (and
  AXI4-Lite when enabled).

## Out of Scope (Initial Release)

- Non-AXI bus protocols.
- Runtime reconfiguration of the register map.
- GUI-based waveform or simulation features.
