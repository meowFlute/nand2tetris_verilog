module dmux4way (
    input  wire in,
    input  wire [1:0] sel,
    output wire a,
    output wire b,
    output wire c,
    output wire d
);

    wire x;
    wire y;

   dmux dmux_bit0   (.in(in), .sel(sel[0]), .a(x), .b(y));
   dmux dmux_bit1_x (.in(x),  .sel(sel[1]), .a(a), .b(c));
   dmux dmux_bit1_y (.in(y),  .sel(sel[1]), .a(b), .b(d));

endmodule
