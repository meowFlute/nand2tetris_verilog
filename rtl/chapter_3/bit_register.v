module bit_register (
    input wire clk,
    input wire  in,
    input wire  load,
    output wire out
);
    wire input_to_dff;

    /* the book showed this as simply being a mux in front of a DFF where one
     * input to the mux was the output of the dff */
    mux load_selector (.a(out), .b(in), .sel(load), .out(input_to_dff));
    dff internal_dff  (.in(input_to_dff), .clk(clk), .out(out));

endmodule
