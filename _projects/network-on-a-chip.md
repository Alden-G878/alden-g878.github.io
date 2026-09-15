---
title: "Network-on-a-Chip"
published: true
date_start: 2025-01-01
date_end: 2025-05-01   # null = ongoing
status: complete
context: personal
team_size: 1
role: solo
categories:
  - computer-architecture
  - rtl-design
tech_stack:
  - "packet routing"
  - "FIFO buffers"
flagship: false
summary: >
  Four-port packet routing hardware with interconnected routers and fair packet flow, simulated end to end.
metrics:
  []
notes_missing_data: true
---

- Designed and simulated four port packet routing hardware supporting interconnected routers and fair packet flow between ports

- Parallel FIFO buffers and internal counters ensure high throughput despite large data flow

- Address logic enabled packet transmission through multiple routers to reach the destination

- Internal data representation minimized packet latency through the router
