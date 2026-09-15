---
title: "USB 2.0 Hardware"
published: true
date_start: 2025-01-01
date_end: 2025-05-01   # null = ongoing
status: complete
context: personal
team_size: 1
role: solo
categories:
  - rtl-design
  - embedded-systems
tech_stack:
  - "USB 2.0"
  - "pipelining"
flagship: false
summary: >
  A pipelined USB 2.0 implementation, eight-way parallelised to move data eight times faster than a serial design.
metrics:
  - "8 times faster than a serial design, via 8-way pipelining"
notes_missing_data: false
---

- Implemented read and write operations

- 8-way pipelined and parallelized design enables rapid data transmission and reception, 8 times faster than a serial design

- Custom orchestration hardware enables device-to-device transfers without a host OS
