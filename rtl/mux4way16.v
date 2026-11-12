module mux4way16 (
    input  wire [15:0] a,
    input  wire [15:0] b,
    input  wire [15:0] c,
    input  wire [15:0] d,
    input  wire  [1:0] sel,
    output wire [15:0] out
);

    wire [15:0] x;
    wire [15:0] y;

    mux16 mux16_ab (.a(a), .b(b), .sel(sel[0]), .out(x));
    mux16 mux16_cd (.a(c), .b(d), .sel(sel[0]), .out(y));
    mux16 mux16_xy (.a(x), .b(y), .sel(sel[1]), .out(out));

endmodule
