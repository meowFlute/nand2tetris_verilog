module or16 (
    input  wire [15:0] a,
    input  wire [15:0] b,
    output wire [15:0] out
);

    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : bit_or
            or_gate derived_or (.a(a[i]), .b(b[i]), .out(out[i]));
        end
    endgenerate
endmodule
