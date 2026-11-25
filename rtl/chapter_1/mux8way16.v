module mux8way16 (
    input  wire [15:0] a,
    input  wire [15:0] b,
    input  wire [15:0] c,
    input  wire [15:0] d,
    input  wire [15:0] e,
    input  wire [15:0] f,
    input  wire [15:0] g,
    input  wire [15:0] h,
    input  wire  [2:0] sel,
    output wire [15:0] out
);

    wire [15:0] x;
    wire [15:0] y;

    mux4way16 mux_atod (.a(a), .b(b), .c(c), .d(d), .sel(sel[1:0]), .out(x));
    mux4way16 mux_etoh (.a(e), .b(f), .c(g), .d(h), .sel(sel[1:0]), .out(y));
    mux16 mux16_xy (.a(x), .b(y), .sel(sel[2]), .out(out));

endmodule
