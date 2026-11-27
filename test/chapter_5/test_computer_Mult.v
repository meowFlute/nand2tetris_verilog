`timescale 1ns/1ps
// Runs a program on the full computer and checks RAM[2] = RAM[0] * RAM[1].
// Run with:  vvp build/chapter_5/test_computer +program=src/chapter_4/Mult.hack
module test_computer;
    reg         clk = 0;
    reg         reset = 1;
    reg  [15:0] key = 16'd0;

    computer #(.PROGRAM("src/chapter_4/Mult.hack")) dut (.clk(clk), .reset(reset), .key(key));

    always #5 clk = ~clk;

    // RAM16K lives at dut.mem.ram.mem[]
    initial begin
        dut.mem.ram.mem[0] = 16'd6;     // R0
        dut.mem.ram.mem[1] = 16'd7;     // R1
        dut.mem.ram.mem[2] = 16'd0;     // R2 (product goes here)

        // hold reset for two clock edges, then let the program run
        repeat (2) @(posedge clk);
        #1 reset = 0;

        repeat (500) @(posedge clk);
        #1;

        if (dut.mem.ram.mem[2] === 16'd42)
            $display("PASS: R2 = %0d", dut.mem.ram.mem[2]);
        else
            $display("FAIL: R2 = %0d (expected 42)", dut.mem.ram.mem[2]);
        $finish;
    end
endmodule
