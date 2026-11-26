// AM= writes memory at the OLD A, and a jump uses the A from before the instruction
@10
AM=A+1          // RAM[10] = 11, A = 11
D=A
@0
M=D             // RAM[0] = 11
@3
D=A-1
@1
M=D             // RAM[1] = 2
@SKIP
D=-1
D;JLT           // taken: jumps to SKIP (A is still SKIP here)
@7
M=1             // must be skipped
(SKIP)
@2
M=-1            // RAM[2] = 0xFFFF
// signed compare: -16384 < 0, and 0x7FFF + 1 wraps negative
@16384
D=A
D=D+A           // 0x8000 = -32768
@NEG
D;JLT
@8
M=1             // must be skipped
(NEG)
@3
M=D             // RAM[3] = -32768
(HALT)
@HALT
0;JMP
