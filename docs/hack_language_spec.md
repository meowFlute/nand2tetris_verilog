# Hack Machine Language Specification

## The A-instruction

### assembly language representation:

```
@value // Where value is either a non-negative decimal number or a symbol referring to such a number
```

### binary representation

It is identified as an instruction beginning with 0

```
0vvv vvvv vvvv vvvv // Where v is a value 0 or 1
```

The A-instruction is used to set the 15-bit value in the A register.

### Use Cases

The A-instruction is used for 3 purposes:
1. provides the only method of entering a constant into the computer under program control
2. Sets the stage for a subsequent C-instruction designed to manipulate a certain data memory location by first setting A to the address of that location
3. It sets the stage for a C-instruction that specifies a jump by first loading the address of th jump destination into the A register

## The C-instruction

### assembly language representation:

```
dest=comp;jump  // Either the dest or the jump fields may be empty.
                // If dest is empty, the "=" is omitted;
                // If jump is empty, the ";" is omitted.
```

### binary representation

The leftmost bit is 1, the next two are not used (always 1). The remaining form three fields 

```
111a cccc ccdd djjj // Where: 
                    //   - a is an operating bit on the compute field (see below in the computation spec)
                    //   - c is a 6-bit field that instructs the ALU what to compute,
                    //   - d is a 3-bit destination of ALU output,
                    //   - j is a 3-bit field specifying a jump condition
```

#### The computation specification

The compute field of the C-instruction is given by the following table:

| when a=0 | c1 | c2 | c3 | c4 | c5 | c6 | when a=1 |
|----------|----|----|----|----|----|----|----------|
|  0       | 1  | 0  | 1  | 0  | 1  | 0  |          |
|  1       | 1  | 1  | 1  | 1  | 1  | 1  |          |
| -1       | 1  | 1  | 1  | 0  | 1  | 0  |          |
|  D       | 0  | 0  | 1  | 1  | 0  | 0  |          |
|  A       | 1  | 1  | 0  | 0  | 0  | 0  |  M       |
| !D       | 0  | 0  | 1  | 1  | 0  | 1  |          |
| !A       | 1  | 1  | 0  | 0  | 0  | 1  | !M       |
| -D       | 0  | 0  | 1  | 1  | 1  | 1  |          |
| -A       | 1  | 1  | 0  | 0  | 1  | 1  | -M       |
|  D+1     | 0  | 1  | 1  | 1  | 1  | 1  |          |
|  A+1     | 1  | 1  | 0  | 1  | 1  | 1  | M+1      |
|  D-1     | 0  | 0  | 1  | 1  | 1  | 0  |          |
|  A-1     | 1  | 1  | 0  | 0  | 1  | 0  | M-1      |
|  D+A     | 0  | 0  | 0  | 0  | 1  | 0  | D+M      |
|  D-A     | 0  | 1  | 0  | 0  | 1  | 1  | D-M      |
|  A-D     | 0  | 0  | 0  | 1  | 1  | 1  | M-D      |
|  D&A     | 0  | 0  | 0  | 0  | 0  | 0  | D&M      |
|  D|A     | 0  | 1  | 0  | 1  | 0  | 1  | D|M      |

#### The destination specification

The three bits of the destination are independent and one, more than one, or none can be asserted simultaneously. They are:
1. bit 1: store the computed value in the A register
2. bit 2: store the computed value in the D register
3. bit 3: store he computed value in M (i.e. Memory[A])

| d1 | d2 | d3 | Mnemonic | Destination      | 
|----|----|----|----------|------------------|
| 0  | 0  | 0  | null     | value not stored | 
| 0  | 0  | 1  | M        | Memory[A]        |
| 0  | 1  | 0  | D        | D register       |
| 0  | 1  | 1  | MD       | Memory[A] and D register  |
| 1  | 0  | 0  | A        | A register       |
| 1  | 0  | 1  | AM       | Memory[A] and A register  |
| 1  | 1  | 0  | AD       | both registers A and D |
| 1  | 1  | 1  | AMD      | all three | 

#### The jump specification

The jump proceeds to the address in A. Labels can be used and must be loaded into A with an A-instruction prior to the jump

| j1 | j2 | j3 | Mnemonic | Effect |
|----|----|----|----------|--------|
| 0  | 0  | 0  | null     | no jump (; can be omitted in asm) |
| 0  | 0  | 1  | JGT      | If out > 0 jump |
| 0  | 1  | 0  | JEQ      | If out = 0 jump |
| 0  | 1  | 1  | JGE      | If out >= 0 jump |
| 1  | 0  | 0  | JLT      | If out < 0 jump |
| 1  | 0  | 1  | JNE      | If out != 0 jump |
| 1  | 1  | 0  | JLE      | If out <= 0 jump |
| 1  | 1  | 1  | JMP      | unconditional jump (0 typically precedes the ; in asm, but the compute is ignored and is arbitrary) |

**NOTE:** good rule of thumb that a C-instruction containing a jump (non-zero j bits) should NOT reference M to not misconstrue the usage of A

## Special Symbols

### Predefined Symbols
There is a special subset of RAM addresses that can be referred to by any assembly program using the following predefined symbols:
- **virtual registers:** `R0` to `R15` refer to addresses 0 to 15 respectively
- **predefined pointers:** The symbols `SP`, `LCL`, `ARG`, `THIS`, and `THAT` are predefined to refer to RAM addresses 0 to 4 respectively (same as R0-R4 -- they have two labels)
- **I/O pointers:** The symbols `SCREEN` and `KBD` are predefined to refer to RAM addresses 16384 (0x4000) and 24576 (0x6000) respectively, which are the base addresses to the screen and keyboard memory maps.

### Label Symbols
The user-defined symbols which serve to label destinations of goto commands are declared by the pseudo-command `(Xxx)`. This predefines
the symbol `Xxx` to refer to the instruction memory location holding the next command in the program. A label can be defined once and only once
and can be used anywhere in the assembly program, even before the line in which it is defined

### Variable Symbols:
Any user-defined symbol `Xxx` appearing in an assembly program that is not predefined and is not defined elsewhere using the `(Xxx)` command is treated as a *variable*, and is assigned a unique memory address by the assembler, starting with RAM address 16 (0x0010).

## Input/Output Handling
The screen an keyboard are memory mapped to predefined locations. Pixels are a read/write bit, keyboard keys are a read-only RAM bit.

### Screen
The screen is black and white `1 = black`, `0 = white`, organized in 256 rows of 512 pixels per row. It is represented as an 8K memory map that starts at memory
address 16384 (0x4000). Each row starting in the top left corner is represented by 32 consecutive 16-bit words. It counts from LSB to MSB.

A formula for the pixel location is:

```
RAM[16384 + r*32 + c/16]    // the register address containing the pixel at row r from the top and column c from the left
c%16                        // the bit within the register
```

an example of setting the address and then manipulating a bit that uses the predefined symbol `SCREEN` would be as follows:

```
@SCREEN     // Set the A register to 0x4000 (the top-left-most pixel)
M=1         // Set the top-left-most pixel black (Memory[0x4000] to 1)
```

### Keyboard
The keyboard is mapped to a single word at address 24576 (0x6000). Whenever a key is pressed on the physical keyboard, a 16-bit ASCII
code appears in RAM[24576]. When no key is pressed it is all zeros. In addition to the usual ASCII codes, the hack keyboard also recognizes
the following keys:

| Key Pressed | Code |
|-------------|------|
| newline     | 128  |
| backspace   | 129  |
| left arrow  | 130  |
| up arrow    | 131  |
| right arrow | 132  |
| down arrow  | 133  |
| home        | 134  |
| end         | 135  |
| page up     | 136  |
| page down   | 137  |
| insert      | 138  |
| delete      | 139  |
| esc         | 140  |
| f1-f12      | 141-152 |

## Syntax and File Format

### Binary Code Files
binary files are ASCII where each command is 16-bits on a row (1s or 0s), and the implicit program memory address is the row of the file (starting at 0). 

### Constants and Symbols
*Constants* must be non-negative and are always written in decimal notation (not hexidecimal).

A user-defined *Symbol* can be any sequence of letters, digits, underscore "\_", dot ".", dollar sign "$", and colon ":" that does not begin with a digit

### Comments 
Text beginning with two slashes and ending at the end of the line is a comment

### White Space
White space is ignored

### Case convention
All assembly mnemonics are uppercase. The rest is case sensitive (labels, user-defined symbols, etc.) The convention is to use
uppercase for labels and lowercase for variable names
