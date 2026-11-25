module pc (
    input  wire        clk,
    input  wire [15:0] in,
    input  wire        inc,
    input  wire        load,
    input  wire        reset,
    output wire [15:0] out
);
    wire [15:0] q;            // current value, fed back
    wire [15:0] incremented;
    wire [15:0] after_inc;
    wire [15:0] after_load;
    wire [15:0] next;
    wire        not_reset;

    // q + 1
    inc16 incrementer (.in(q), .out(incremented));

    // inc: choose q or q+1
    mux16 inc_mux  (.a(q),         .b(incremented), .sel(inc),  .out(after_inc));
    // load: overrides inc
    mux16 load_mux (.a(after_inc), .b(in),          .sel(load), .out(after_load));

    // reset: overrides everything. AND every bit with !reset to force zeros
    not_gate reset_inv (.in(reset), .out(not_reset));
    and16 reset_gate (.a(after_load), .b({16{not_reset}}), .out(next));

    // the muxes decide the new value, so the register always loads
    register16 state (.clk(clk), .in(next), .load(1'b1), .out(q));

    assign out = q;
endmodule
