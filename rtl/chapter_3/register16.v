module register16 (
    input  wire clk,
    input  wire [15:0] in,
    input  wire load,
    output wire [15:0] out
);

    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : bit_registers
            bit_register single_bit (.clk(clk), .in(in[i]), .load(load), .out(out[i]));
        end
    endgenerate
endmodule
