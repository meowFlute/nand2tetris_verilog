// Screen memory map: 8K words (two 4K RAMs).
module screen (
    input         clk,
    input  [15:0] in,
    input         load,
    input  [12:0] address,
    output [15:0] out
);
    wire load_lo, load_hi;
    wire [15:0] out_lo, out_hi;

    dmux dm (.in(load), .sel(address[12]), .a(load_lo), .b(load_hi));
    ram4k ram_lo (.clk(clk), .in(in), .load(load_lo), .address(address[11:0]), .out(out_lo));
    ram4k ram_hi (.clk(clk), .in(in), .load(load_hi), .address(address[11:0]), .out(out_hi));
    mux16 mx (.a(out_lo), .b(out_hi), .sel(address[12]), .out(out));
endmodule
