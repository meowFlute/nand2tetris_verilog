module or8way (
    input  wire [7:0] in,
    output wire out
);

    wire [5:0] w;
    genvar i;

    or_gate first_or (.a(in[0]), .b(in[1]), .out(w[0]));
    generate
        for (i = 1; i < 6; i = i + 1) begin : bit_or
            or_gate derived_or (.a(in[i+1]), .b(w[i-1]), .out(w[i]));
        end
    endgenerate
    or_gate last_or (.a(in[7]), .b(w[5]), .out(out));

endmodule
