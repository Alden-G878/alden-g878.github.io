---
title: "IC I/O Harness on Commercial Processes and Tools"
published: true
date_start: 2025-10-01
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
  - "180nm PDK"
  - "ADPLL"
  - "SPICE"
  - "SystemVerilog"
  - "Cadence"
  - "PCB bring-up"
publication_status: none
flagship: true
summary: >
  All-digital PLL and bring-up work for the group's I/O harness: a 180nm ADPLL
  targeting a 16-fold clock increase that was shelved before tape-out,
  voltage-domain circuitry for the harness carrier board, and a TSMC 28nm chip
  with an ADPLL and a three-body physics engine targeting a December 2026
  tape-out.
metrics: []
---

- Designing an all-digital PLL (ADPLL) and a physics engine simulating three-body gravitational interactions for a TSMC 28nm test chip, targeting a December 2026 tape-out; the ADPLL targets a 16-fold clock increase

- Contributing to I/O pad ring physical design for that chip under a PhD student, including ring layout, power and ground distribution, and DRC/LVS closure

- Designed the voltage-domain circuitry for the harness carrier board: FPGA-configurable regulators supplying custom voltage domains

- Designed a 180nm ADPLL targeting the same 16-fold clock increase, up to 320 MHz from a 20 MHz reference, and its FPGA fabric with a partner; that chip was shelved before tape-out

- Technologies: SystemVerilog RTL, Cadence synthesis and simulation, SPICE
