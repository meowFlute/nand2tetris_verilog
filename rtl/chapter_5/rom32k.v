// 32K x 16 instruction ROM. Behavioral (it's storage for the program, not logic).
// Load a program with:  vvp build/chapter_5/test_computer +program=src/chapter_4/Mult.hack
module rom32k #(parameter PROGRAM = "program.hack") (
    input  [14:0] address,
    output [15:0] out
);
    reg [15:0] mem [0:32767];
    reg [8*256-1:0] file;
    integer i;

    initial begin
        for (i = 0; i < 32768; i = i + 1) mem[i] = 16'b0;
        if (!$value$plusargs("program=%s", file)) file = PROGRAM;
        $readmemb(file, mem);
    end

    assign out = mem[address];
endmodule
