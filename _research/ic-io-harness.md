---
title: "IC I/O Harness on Commercial Processes and Tools"
published: true
date_start: 2025-11-01
date_end: null              # null = ongoing
status: ongoing
pi: "Ken Mai & Jim Bain"
group: "Mai & Bain Research Group, Carnegie Mellon University"
categories:
  - asic-design
  - analog-mixed-signal
  - fpga
  - pcb-eda
tech_stack:
  - "TSMC 28nm"
  - "PLL"
  - "ring oscillator"
  - "SPICE"
  - "SystemVerilog"
  - "Cadence"
publication_status: none
flagship: true
summary: >
  Part of a taped-out ASIC in TSMC 28nm: a digital PLL and ring oscillator that raised on-chip clock frequency 16-fold, plus FPGA fabric and a PCB carrier board.
metrics:
  - "16-fold increase in on-chip clock frequency, from 20 MHz to 320 MHz"
  - "Redesign targeting a 400 MHz on-chip clock frequency"
---

- Designed a portion of a taped-out ASIC with a focus on PLL, ring oscillators, and FPGA fabric in the TSMC 28nm PDK

- Designed a ring oscillator and digital phase-locked loop for on-chip clock generation, enabling a 16-fold increase in on-chip clock frequency from 20 MHz to 320 MHz

- Redesigning the PLL for a new tape-out, targeting a 400 MHz on-chip clock frequency

- Verifying PLL behavior with SPICE simulation

- Designed custom FPGA fabric to interface with the I/O Harness, helping students familiarize themselves with it without the complicated pitfalls of ASIC design

- Designed a PCB carrier board to interface the finalized ASIC with an external FPGA for bring-up and post-silicon validation

- Technologies: RTL design in SystemVerilog, synthesis and simulation with Cadence
