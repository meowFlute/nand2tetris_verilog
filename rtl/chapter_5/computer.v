// The Hack computer: CPU + ROM32K + Memory.
// Pulse reset=1 then reset=0 to start the loaded program.
module computer #(parameter PROGRAM = "program.hack") (
    input        clk,
    input        reset,
    input [15:0] key        // keyboard input, driven by the testbench
);
    wire [15:0] instruction, mem_out, cpu_out;
    wire        write_m;
    wire [14:0] address_m, pc;

    cpu cpu0 (
        .clk(clk), .inM(mem_out), .instruction(instruction), .reset(reset),
        .outM(cpu_out), .writeM(write_m), .addressM(address_m), .pc(pc)
    );

    rom32k #(.PROGRAM(PROGRAM)) rom (.address(pc), .out(instruction));

    memory mem (
        .clk(clk), .in(cpu_out), .load(write_m), .address(address_m),
        .key(key), .out(mem_out)
    );
endmodule
