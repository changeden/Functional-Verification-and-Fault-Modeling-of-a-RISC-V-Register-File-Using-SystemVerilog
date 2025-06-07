# Functional-Verification-and-Fault-Modeling-of-a-RISC-V-Register-File-Using-SystemVerilog


🛠️ RISC-V Register File Verification & Fault Modeling
This project implements and verifies a 32×32 RISC-V-compatible register file in Verilog, supporting:

Dual read ports, single write port

x0 hardwired to zero

A SystemVerilog testbench validates functionality with directed and randomized tests, covering:

Read/write correctness

Edge cases (e.g., x0 writes, simultaneous accesses)

Fault modeling (stuck-at, bit-flip)

Assertions & waveform analysis

Coverage collection and regression automation
