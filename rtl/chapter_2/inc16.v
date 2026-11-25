module inc16 (
    input wire [15:0] in,
    output wire [15:0] out
);

    genvar i;
    wire [15:0] c;

    /* fist bit is just added to 1 */
    half_adder lsb_add (.a(in[0]), .b(1'b1), .sum(out[0]), .carry(c[0]));
    
    /* the following bits all follow a similar format and can be generated
     * half-adders using a for loop */
    generate
        for (i = 1; i < 16; i = i + 1) begin : bit_add
            half_adder lsb_add (.a(in[i]), .b(c[i-1]), .sum(out[i]), .carry(c[i]));
        end
    endgenerate

endmodule
