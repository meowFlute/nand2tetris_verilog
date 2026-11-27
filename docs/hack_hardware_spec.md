# Hack Platform Specification

## Overview

From the book:

> The Hack platform is a 16-bit von Neumann machine, consisting of a CPU, two separate memory modules serving as instruction memory and 
> data memory, and two memory-mapped I/O devices: a screen and a keyboard.

It follows a single fetch-execute cycle (every CPU cycle it completes a fetch and an execution) with the following definitions:

### Fetch

Which instruction to fetch from instruction memory next is determined by the jump bits of the current instruction and the ALU output 
(and the first instruction to fetch will be loaded at instruction memory address 0x0000). If a jump should be executed, the PC is set 
to the value of the A-register. Otherwise, it is incremented by 1. At program start it is set to 0.

### Execute

Instructions can be of two types: Address Instructions, and Compute Instructions. All instructions complete execution in the single cycle.

#### Address Instruction Execution

If the most significant bit is 0 then the A register is loaded with the other 15 bits of the instruction

#### Compute Instruction Execution

If the most significant bit is a 1, it's a-, c-, d-, and j- bits cause the ALU and the registers to execute the next instruction.

## CPU

The CPU is designed to execute 16-bit instructions according to the machine language spec in `docs/hack_language_spec.md`. It expects
to be connected to instruction memory from which it fetches the instructions for execution and data memory from which it can read and
write data values.

- **Chip Name:** `CPU` (Central Processing Unit)
- **Inputs:** 
    - `inM[16]`: `M` value input which is the contents of `RAM[A]`
    - `instruction[16]`: Instruction for execution
    - `reset`: signals whether to restart the current program or continue executing
- **Outputs:**
    - `outM[16]`: `M` value output which is stored in `RAM[A]`
    - `writeM`: write to M?
    - `addressM[15]`: Address of `M` in data memory
    - `pc[15]`: address of the next instruction
- **Functions**: 
    - Executes instructions according to the `docs/hack_language_spec.md`. The `D` and `A` int he language spec refer
    to CPU-resident registers. `M` refers to the memory location addressed by `A` (`inM` holds the value of this location).
    - If the instruction needs to write to `M`, the value is places in `outM`, the address in `addressM` and the write bit is
    asserted. When `writeM = 0` any value may appear in `outM`. 
    - If `reset=1`, then the CPU jumps to instruction address 0 (i.e. sets `PC = 0` in the next time unit) rather than to the 
    address resulting from the current instruction.

## Instruction Memory

direct-access Read-Only Memory (ROM) dedicated for instructions consists of 32K addressable 16-bit registers.

- **Chip Name:** `ROM32K`
- **Input:** `address[15]`: from the value in `pc[15]`
- **Output:** `out[16]`: value of `ROM[address]`
- **Function:** `out=ROM[address]`: direct-read of 16-bit instructions at `address[15]`
- **Comment:**
    - The ROM is assumed to be preloaded with a machine language program. Hardware implementations can treat the ROM as a built-in chip.
    Software simulators must supply a mechanism for loading a program into ROM.

## Data Memory

Same interface as the chips built (`ram16.v` to be specific) and tested in chapter 3 (I'm writing this for chapter 5 so I'll skip some details):
- To read the contents of register `n` we put `n` in the memory's address input and probe the memory's `out` output. 
    - Reading is a combinational operation independent of the clock.
- To write a value `v` into register `n` we put `v` in the `in` input and `n` in the address input and assert the memory's load bit.
    - Writing is a sequential operation so register `n` will commit the new value `v` in the next clock cycle.

- **Chip Name:** `RAM16K`: 16384 16-bit registers (requires a 14-bit address)
- **Input:** 
    - `in[16]`: `outM[16]` from the CPU -- the `M` value to be stored in `RAM[A]`
    - `address[14]`: from the LSB values in `A` from the CPU, output as `addressM[15]`
    - `load`: single-bit load wire, `writeM` from the CPU
- **Output:** `out[16]`: value of `RAM[address]`
- **Function:** 
    - `out(t)=RAM[address(t)](t)` 
    - if `load(t-1)` then `RAM[address(t-1)](t)=in(t-1)`

### Memory Maps

As described in various locaions before, there are two memory maps

#### Screen Memory Map

- **Chip Name:** `Screen`
- **Input:** 
    - `in[16]`: `outM[16]` from the CPU -- the `M` value to be stored in `RAM[A]`
    - `load`: single-bit load wire, `writeM` from the CPU
    - `address[13]`: from the value in `addressM[15]` if its MSB is 1 (accessing beyond `RAM16K`)
- **Output:** `out[16]`: value of `RAM[address]`
- **Function:** 
    - `out(t)=RAM[address(t)](t)` 
    - if `load(t-1)` then `RAM[address(t-1)](t)=in(t-1)`
- **Comment:**
    - This functions exactly like `RAM8K` from chapter 3. Has the side effect of continuously refreshing a 256 by 512 black-and-white
    screen device (simulators must simulate the device). Each row is 32 consecutive 16-bit words, starting at the top-left corner of
    the screen. Thus the pixel at row `r` from the top and column `c` from the left (`0 <= r <= 255; 0 <= c <= 511`) reflects the `c%16`
    bit (counting from LSB to MSB) of the word found at `SCREEN[r*32+c/16]`.

#### Keyboard Memory Map

- **Chip Name:** `Keyboard`
- **Output:** `out[16]`: ascii code of the pressed key, or one of the special codes listed in `docs/hack_language_spec.md` or 0 if nothing is pressed
- **Function:** pretty simple, outputs the code of the current key pressed as described in **output:**
- **Comment:** This chip is continuously refreshed from a physical keyboard unit (simulators must simulate this service).

## Overall Memory

All of the non-ROM / non-program-instruction memory listed above is in a single monolithic address space, with `RAM16K` first at 
address 0x0000, then `Screen` at 0x4000, and `Keyboard` at 0x6000.

- **Chip Name:** `Memory`
- **Input:** 
    - `in[16]`: `outM[16]` from the CPU -- the `M` value to be stored in `RAM[A]`
    - `load`: single-bit load wire, `writeM` from the CPU
    - `address[15]`: from the value in `addressM[15]`
- **Output:** `out[16]`: value of `RAM[address]`
- **Function:** 
    - `out(t)=RAM[address(t)](t)` 
    - if `load(t-1)` then `RAM[address(t-1)](t)=in(t-1)`
- **Comment:**
    - access to anything beyond 0x6000 is invalid. 

## Computer

The topmost chip just has a reset input and runs the program

- **Chip Name:** `Computer`
- **Input:** `reset`
- **Function:** 
    - When reset is 0 the program stored in ROM executes. When reset is 1, the execution of the program restarts. Thus to start
    the programs execution the reset must be pushed (1) and then released (0). While executing the user interacts with the keyboard
    and screen.
