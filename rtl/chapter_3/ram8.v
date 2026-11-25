module ram8 (
    input  wire clk,
    input  wire [15:0] in,
    input  wire [2:0]  address,
    input  wire        load,
    output wire [15:0] out
);

    wire [7:0]  l;
    wire [15:0] register16_out [0:7];
    genvar i;

    // demux the load signal
    dmux8way load_demuxer ( 
        .in(load), .sel(address), 
        .a(l[0]), .b(l[1]), .c(l[2]), .d(l[3]), 
        .e(l[4]), .f(l[5]), .g(l[6]), .h(l[7]) );
    
    // generate the 3-bit address space
    generate 
        for (i = 0; i < 8; i = i + 1) begin : internal_registers
            register16 internal_register ( .clk(clk), .in(in), .load(l[i]), .out(register16_out[i]) );
        end
    endgenerate
    
    // mux the signals at the end
    mux8way16 output_selector (
        .a(register16_out[0]), 
        .b(register16_out[1]), 
        .c(register16_out[2]), 
        .d(register16_out[3]), 
        .e(register16_out[4]), 
        .f(register16_out[5]), 
        .g(register16_out[6]), 
        .h(register16_out[7]),
        .sel(address),
        .out(out)
    );

endmodule
