// Keyboard memory map: a single read-only word.
// The testbench (or emulator front end) drives `key` with the current keycode.
module keyboard (
    input  [15:0] key,
    output [15:0] out
);
    assign out = key;
endmodule
