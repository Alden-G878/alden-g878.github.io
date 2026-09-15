---
title: "7-stage Patterson and Hennessy style RV32I Core"
published: true
date_start: 2026-01-01
date_end: 2026-05-01   # null = ongoing
status: complete
context: personal
team_size: 1
role: solo
categories:
  - computer-architecture
  - rtl-design
tech_stack:
  - "SystemVerilog"
  - "RV32I"
  - "pipelining"
  - "branch prediction"
flagship: true
summary: >
  A 7-stage Patterson-and-Hennessy-style RV32I processor core in SystemVerilog, with forwarding, a two-bit branch predictor and cache-conflict arbitration.
metrics:
  - "More than 5x faster than the naive approach on real-world RV32I programs"
  - "Branch prediction accuracy doubled, from 40% to 80%"
notes_missing_data: false
---

- Implemented an RV32I core in SystemVerilog with 7 pipeline stages

- Maximal forwarding between pipeline stages minimized data-dependent stalling. The final implementation was more than 5 times faster than the naive approach using real-world RV32I programs

- Designed a two-bit branch predictor with a branch target buffer that doubled accurate branch predictions from 40% to 80%

- Implemented a cache-management solution that successfully arbitrated cache conflicts inherent in non-atomic bus snooping systems
