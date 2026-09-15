---
title: "Physics Engine ASIC"
published: true
date_start: 2025-12-01
date_end: null   # null = ongoing
status: ongoing
context: personal
team_size: 1
role: solo
categories:
  - asic-design
  - rtl-design
  - verification
tech_stack:
  - "Sky130"
  - "TinyTapeout"
  - "SystemVerilog"
  - "Cocotb"
  - "Python"
  - "QSPI"
  - "VGA"
flagship: true
summary: >
  A taped-out ASIC implementing a falling sand physics simulation with VGA output. A QSPI memory controller cut on-chip memory to one eighth of its original size.
metrics:
  - "On-chip memory reduced to 1/8 of original size (96 bytes to 12 bytes)"
  - "Clock cycles per physics simulation tick reduced by a factor of three"
notes_missing_data: false
---

- Tape out: Sky130 open source PDK; Fab: TinyTapeout

- Implemented a falling sand simulation with output over VGA

- QSPI memory controller reduced required on-chip memory to 1/8 of original size (from 96 bytes to 12 bytes)

- Complete ASIC design flow: RTL design, RTL simulation/debug, netlist generation, place and route, GDSII generation

- Reduced clock cycles per physics simulation tick by a factor of three by adapting a physics simulation technique from graphics programming

- Utilized RTL waveform debugging to fix bugs in the RTL design

- Interfaced with external RAM hardware via QSPI, requiring intra-clock edge timing control

- Leveraged fixed-delay digital buffers to ensure all protocols are obeyed

- Constructed a test bench using Cocotb and Python, and verified functionality with assertions and constrained random testing
