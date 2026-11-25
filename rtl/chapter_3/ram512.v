module ram512 (
    input  wire        clk,
    input  wire [15:0] in,
    input  wire [8:0]  address,
    input  wire        load,
    output wire [15:0] out
);
    /* This way is so slow to compile lol -- the book says at some point to
    * move to abstract memory because compilation times and simulation times
    * get exponentially worse (literally) */
    
    /*
    wire [7:0]   l;
    wire [127:0] ram64_out;

    dmux8way load_demuxer (
        .in(load), .sel(address[8:6]),
        .a(l[0]), .b(l[1]), .c(l[2]), .d(l[3]),
        .e(l[4]), .f(l[5]), .g(l[6]), .h(l[7])
    );

    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : internal_ram64
            ram64 ram_inst (
                .clk(clk), .in(in), .address(address[5:0]),
                .load(l[i]), .out(ram64_out[i*16 +: 16])
            );
        end
    endgenerate

    mux8way16 output_selector (
        .a(ram64_out[  0 +: 16]), .b(ram64_out[ 16 +: 16]),
        .c(ram64_out[ 32 +: 16]), .d(ram64_out[ 48 +: 16]),
        .e(ram64_out[ 64 +: 16]), .f(ram64_out[ 80 +: 16]),
        .g(ram64_out[ 96 +: 16]), .h(ram64_out[112 +: 16]),
        .sel(address[8:6]),
        .out(out)
    );
    */

    reg [15:0] mem [0:511];

    // synchronous write
    always @(posedge clk) begin
        if (load)
            mem[address] <= in;
    end

    // combinational read, same as the structural versions
    assign out = mem[address];

endmodule
