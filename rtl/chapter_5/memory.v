// Hack data memory: RAM16K (0x0000-0x3FFF), Screen (0x4000-0x5FFF), Keyboard (0x6000).
module memory (
    input         clk,
    input  [15:0] in,
    input         load,
    input  [14:0] address,
    input  [15:0] key,
    output [15:0] out
);
    wire ram_load, other_load, screen_load, not_a13;
    wire [15:0] ram_out, screen_out, kbd_out;

    // address[14]=0 -> RAM; address[14]=1 -> Screen or Keyboard (address[13] picks)
    dmux     dm_load (.in(load), .sel(address[14]), .a(ram_load), .b(other_load));
    not_gate n_a13   (.in(address[13]), .out(not_a13));
    and_gate and_scr (.a(not_a13), .b(other_load), .out(screen_load));

    ram16k   ram (.clk(clk), .in(in), .load(ram_load),    .address(address[13:0]), .out(ram_out));
    screen   scr (.clk(clk), .in(in), .load(screen_load), .address(address[12:0]), .out(screen_out));
    keyboard kbd (.key(key), .out(kbd_out));

    mux4way16 mx (.a(ram_out), .b(ram_out), .c(screen_out), .d(kbd_out),
                  .sel(address[14:13]), .out(out));
endmodule
