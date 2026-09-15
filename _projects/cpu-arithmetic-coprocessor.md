---
title: "CPU Arithmetic Coprocessor and Microcode Modification"
published: true
date_start: 2024-09-01
date_end: 2024-12-01   # null = ongoing
status: complete
context: personal
team_size: 1
role: solo
categories:
  - computer-architecture
  - rtl-design
tech_stack:
  - "microcode"
  - "coprocessor"
  - "multicycle CPU"
flagship: false
summary: >
  Microarchitecture and microcode changes to a multicycle CPU adding double-word arithmetic via an arithmetic coprocessor.
metrics:
  []
notes_missing_data: true
---

- Modified a multicycle CPU to support double-word arithmetic operations via microarchitecture changes to interface with an arithmetic coprocessor

- Coprocessor design minimized instruction decode logic and microcode architecture, and eliminated software-based data dependence hazards using hardware solutions
