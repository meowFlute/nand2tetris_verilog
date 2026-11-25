module ram64 (
    input  wire        clk,
    input  wire [15:0] in,
    input  wire [5:0]  address,
    input  wire        load,
    output wire [15:0] out
);
    wire [7:0]   l;
    wire [127:0] ram8_out;

    dmux8way load_demuxer (
        .in(load), .sel(address[5:3]),
        .a(l[0]), .b(l[1]), .c(l[2]), .d(l[3]),
        .e(l[4]), .f(l[5]), .g(l[6]), .h(l[7])
    );

    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : internal_ram8
            ram8 ram_inst (
                .clk(clk), .in(in), .address(address[2:0]),
                .load(l[i]), .out(ram8_out[i*16 +: 16])
            );
        end
    endgenerate

    mux8way16 output_selector (
        .a(ram8_out[  0 +: 16]), .b(ram8_out[ 16 +: 16]),
        .c(ram8_out[ 32 +: 16]), .d(ram8_out[ 48 +: 16]),
        .e(ram8_out[ 64 +: 16]), .f(ram8_out[ 80 +: 16]),
        .g(ram8_out[ 96 +: 16]), .h(ram8_out[112 +: 16]),
        .sel(address[5:3]),
        .out(out)
    );
endmodule
