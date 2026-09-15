---
title: "Decision Tree Training Accelerator"
published: true
date_start: 2025-09-01
date_end: 2025-12-01   # null = ongoing
status: complete
context: personal
team_size: 1
role: solo
categories:
  - hardware-acceleration
  - rtl-design
tech_stack:
  - "decision trees"
  - "Gini score"
  - "square root"
flagship: false
summary: >
  Hardware threads accelerating decision-tree training, including custom square-root hardware that cut cycles per calculation from 11 to 1.
metrics:
  - "Cycles per square-root calculation improved from 11 to 1"
notes_missing_data: false
---

- Designed a series of hardware threads that accelerated decision tree machine learning algorithm training

- Calculated Gini score using custom designed multiplication and division hardware threads

- Leveraged arithmetic properties of numerical representation to bypass expensive computations

- Custom hardware for square roots improved cycles per calculation from 11 to 1
