module not16 (
    input  wire [15:0] in,
    output wire [15:0] out
);

    // let's try a for loop -- haven't done one of those in verilog yet
    // one thing that is a little weird is if you don't name these blocks
    // (named bit_not below) then verilog just seems to make up a name and it
    // can show up in downstream stuff like the graphs
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : bit_not
            not_gate derived_not (.in(in[i]), .out(out[i]));
        end
    endgenerate
endmodule
