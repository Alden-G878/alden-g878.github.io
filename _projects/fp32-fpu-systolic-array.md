---
title: "FP32 FPU and Neural Network Systolic Array"
published: true
date_start: 2025-09-01
date_end: 2025-12-01   # null = ongoing
status: complete
context: personal
team_size: 1
role: solo
categories:
  - hardware-acceleration
  - computer-architecture
tech_stack:
  - "IEEE 754"
  - "systolic array"
  - "neural networks"
flagship: false
summary: >
  IEEE 754 32-bit floating-point hardware with custom multiplication and division architectures, used inside a systolic array to accelerate neural-network inference.
metrics:
  []
notes_missing_data: true
---

- Designed IEEE 754 compatible hardware for computing 32-bit floating point operations

- Supports all arithmetic operations (add, subtract, multiply, divide)

- Performed mathematical modeling to optimize the addition system for power, performance, and area

- Custom multiplication and division architecture enabled single-cycle operation and low-impact change to a highly pipelined design

- Implemented the FP unit in a systolic array used to accelerate inference of a deep neural network
