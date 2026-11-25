module add16 (
    input wire [15:0] a,
    input wire [15:0] b,
    output wire [15:0] out
);

    genvar i;
    wire [15:0] c;

    /* first bit doesn't have an incoming carry bit and can be a half-adder */
    half_adder lsb_add (.a(a[0]), .b(b[0]), .sum(out[0]), .carry(c[0]));
    /* the following bits all follow a similar format and can be generated
     * full-adders using a for loop */
    generate
        for (i = 1; i < 16; i = i + 1) begin : bit_add
            full_adder bit_adder (.a(a[i]), .b(b[i]), .c(c[i-1]), .sum(out[i]), .carry(c[i]));
        end
    endgenerate

endmodule
