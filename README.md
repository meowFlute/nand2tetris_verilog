# nand2tetris_verilog
nand2tetris in verilog with yosys stats and visualizations!

## Background
Once I got to the ALU in nand2tetris I really wanted to: 
1. understand how this sort of hardware simulation is actually done outside of the nand2tetris browser IDE
2. understand how many NAND gates each of these levels of abstraction had
3. see how the NAND gates were all connected visually and appreciate the majesty of layered abstraction

Sure, it was cool that functionally we were building up to a CPU and so forth, but I wanted to dig deeper.

So, before moving on to Project 3, I decided to answer some of those questions. Here is what I came up with after some googling, some AI help, and some luck

## What did I end up with
I'm now going to do the projects in verilog, and show what I wanted to see using [yosys](https://yosyshq.net/). I run it all through a makefile so my flow for each project is basically:
- write a new verilog module
- write a new verilog test file that check the expected output for that module
- build, test, and get all the info I want by running various `make` commands

Not too much incremental work (it is some) now that the framework is in place to make all new code modules and tests only. We were basically already writing verilog modules as those .hdl files and that language was driving me crazy. Here is an example of how easy it is:

```
scott@scott-MacBookPro8-1:~/nand2tetris/nand2tetris_verilog$ make
creating build dir build...
Compiling build/sim_test_and_gate...
iverilog -g2012 -o build/sim_test_and_gate rtl/and_gate.v rtl/nand_gate.v rtl/not_gate.v test/test_and_gate.v
Compiling build/sim_test_not_gate...
iverilog -g2012 -o build/sim_test_not_gate rtl/and_gate.v rtl/nand_gate.v rtl/not_gate.v test/test_not_gate.v
scott@scott-MacBookPro8-1:~/nand2tetris/nand2tetris_verilog$ make run
=== Running build/sim_test_and_gate ===
Time | a | b | out
------------------
10000 | 0 | 0 | 0
20000 | 0 | 1 | 0
30000 | 1 | 0 | 0
40000 | 1 | 1 | 1
--> AND GATE TEST: PASSED
=== Running build/sim_test_not_gate ===
Time | in | out
---------------
10000 | 0 | 1
20000 | 1 | 0
--> NOT GATE TEST: PASSED
scott@scott-MacBookPro8-1:~/nand2tetris/nand2tetris_verilog$ make stats
MODULE                   NANDS
and_gate                 2
not_gate                 1
scott@scott-MacBookPro8-1:~/nand2tetris/nand2tetris_verilog$ make show
1) and_gate
2) not_gate
Module to view: 1
```

<img width="662" height="699" alt="image" src="https://github.com/user-attachments/assets/05f51a85-7c74-49ff-865c-eb4a3e62e250" />

## My System
I'm currently running on Ubuntu 26.04.1 (Resolute Racoon), with the following versions of tools I'm using:
- Icarus Verilog version 12.0 (stable)
- Yosys 0.52 (git sha1 fee39a3284c90249e1d9684cf6944ffbbcbb8f90)
