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
  A taped-out ASIC implementing a falling sand physics simulation with VGA output. A QSPI memory controller moved the grid state to external RAM, cutting on-chip state to one eighth.
metrics:
  - "On-chip state cut from 96 bytes to 12 bytes (1/8) by moving the grid to external QSPI RAM"
  - "Clock cycles per physics simulation tick reduced by a factor of three"
notes_missing_data: false
---

- Tape out: Sky130 open-source PDK (SkyWater 130nm), via the TinyTapeout shuttle

- Implemented a falling sand simulation with output over VGA

- Moved the simulation grid into external QSPI RAM, leaving a 12-byte on-chip working buffer instead of 96 bytes (1/8 the on-chip state), with the protocol's intra-clock-edge timing closed using fixed-delay buffers

- Complete ASIC design flow: RTL design, RTL simulation/debug, netlist generation, place and route, GDSII generation

- Reduced clock cycles per physics simulation tick by a factor of three by adapting a physics simulation technique from graphics programming

- Utilized RTL waveform debugging to fix bugs in the RTL design

- Constructed a test bench using Cocotb and Python, and verified functionality with assertions and constrained random testing
