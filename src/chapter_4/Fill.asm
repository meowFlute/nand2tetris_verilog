// Runs an infinite loop that listens to the keyboard input. 
// When a key is pressed (any key), the program blackens the screen,
// (writes "black" in every pixel). When no key is pressed, 
// the program clears the screen (writes "white" in every pixel).


// LOOP listens to keyboard input and either jumps to CLEAR_SCREEN or BLACKEN_SCREEN
(LOOP)
    @KBD                // Load 0x6000 into register A
    D=M                 // Read keyboard 16-bit word from M[0x6000] into the D register
    @CLEAR_SCREEN       // Load CLEAR_SCREEN label program memory address into A for potential jump
    D;JEQ               // If [D (keyboard ASCII code) == 0] then jump to CLEAR_SCREEN label
    @BLACKEN_SCREEN     // Else load BLACKEN_SCREEN label program memory address into A for unconditional jump
    0;JMP               // Unconditional jump to blacken screen if any key is pressed

(SET_SCREEN)
    @SCREEN
    D=A
    @curr_address       // set curr_address starting point
    M=D                 // curr_address = SCREEN (16384 == 0x4000) 
(FILL_LOOP)
    @curr_address
    D=M                 // load address value into D
    @KBD
    D=D-A               // compare to KBD address (stopping point)
    @LOOP
    D;JGE               // finished the screen, back to LOOP
    @ARG
    D=M                 // value to write is in ARG
    @curr_address       
    A=M                 // load the current address into A
    M=D                 // M[addr] = value to write
    @curr_address               
    M=M+1               // increment address
    @FILL_LOOP          // loop back to check
    0;JMP               

// call SET_SCREEN with ARG set to 0
(CLEAR_SCREEN)
    @ARG
    M=0
    @SET_SCREEN
    0;JMP

// call SET_SCREEN with ARG set to 65535 (0xFFFF) (all 1's)
(BLACKEN_SCREEN)
    @ARG        // load ARG address into A
    M=-1        // -1 in 2's compiliment should be all 1's
    @SET_SCREEN
    0;JMP       
