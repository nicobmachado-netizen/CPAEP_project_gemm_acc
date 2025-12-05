# CPAEP Project Template
- This project template is for the CPAEP class for the AY 2025-2026 in KU Leuven
- This template serves as a base repository for running RTL simulations.
- Preferrably, setup your work in a linux subsystem with Questasim tool.
- Please use the ESAT computers for this exercise.

# Quick Start
We already prepared the entire Questasim simulation setup for you. Simply invoke the command below to run a simulation without GUI.

```bash
make TEST_MODULE=tb_one_mac_gemm questasim-run
```

To run with a GUI do:

```bash
make TEST_MODULE=tb_one_mac_gemm questasim-run-gui
```

In either case, you should see a log that says:

```bash
Some long log of the previous tests.
...
# Test number: 8
# M: 9, K: 13, N: 10
# GEMM operation completed in 1170 cycles
# Result matrix C verification passed!
# Test number: 9
# M: 11, K: 16, N: 3
# GEMM operation completed in 528 cycles
# Result matrix C verification passed!
# All test tasks completed successfully!
# ** Note: $finish    : tb/tb_one_mac_gemm.sv(286)
#    Time: 410816 ns  Iteration: 0  Instance: /tb_one_mac_gemm
# End time: 10:12:59 on Nov 27,2025, Elapsed time: 0:00:01
# Errors: 0, Warnings: 3
```