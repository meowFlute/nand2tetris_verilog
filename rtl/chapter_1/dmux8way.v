module dmux8way (
    input  wire in,
    input  wire [2:0] sel,
    output wire a,
    output wire b,
    output wire c,
    output wire d,
    output wire e,
    output wire f,
    output wire g,
    output wire h
);

    wire w;
    wire x;
    wire y;
    wire z;

    dmux4way dmux_bits1to0 (.in(in), .sel(sel[1:0]), .a(w), .b(x), .c(y), .d(z));
    dmux dmux_w (.in(w), .sel(sel[2]), .a(a), .b(e));
    dmux dmux_x (.in(x), .sel(sel[2]), .a(b), .b(f));
    dmux dmux_y (.in(y), .sel(sel[2]), .a(c), .b(g));
    dmux dmux_z (.in(z), .sel(sel[2]), .a(d), .b(h));

endmodule
