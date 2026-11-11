module mux16 (
    input  wire [15:0] a,
    input  wire [15:0] b,
    input  wire sel,
    output wire [15:0] out
);

    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : bit_mux
            mux derived_mux (.a(a[i]), .b(b[i]), .sel(sel), .out(out[i]));
        end
    endgenerate
endmodule
