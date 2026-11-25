module alu (
    input wire [15:0] x,
    input wire [15:0] y,
    input wire zx,
    input wire nx,
    input wire zy,
    input wire ny,
    input wire f,
    input wire no,
    output wire [15:0] out,
    output wire zr,
    output wire ng
);
    // intermediate stages of x input
    wire [15:0] zeroed_x;
    wire [15:0] negated_x;
    wire [15:0] arbitrated_x;

    // intermediate stages of y input
    wire [15:0] zeroed_y;
    wire [15:0] negated_y;
    wire [15:0] arbitrated_y;

    // core function outputs and arbitration
    wire [15:0] x_added_y;
    wire [15:0] x_and_y;
    wire [15:0] function_out;

    // output negation and arbitration
    wire [15:0] negated_out;
    
    // zero check flags
    wire lower_any;
    wire upper_any;
    wire any_set;

    /* condition and arbitrate the inputs */
    // if (zx == 1) sets x = 0        // 16-bit constant
    mux16 zx_select (.a(x) , .b(16'h0000) , .sel(zx) , .out(zeroed_x) );
    // if (nx == 1) sets x = !x       // bitwise not
    not16 negate_x (.in(zeroed_x) , .out(negated_x) );
    mux16 nx_select (.a(zeroed_x) , .b(negated_x) , .sel(nx) , .out(arbitrated_x) );
    // if (zy == 1) sets y = 0        // 16-bit constant
    mux16 zy_select (.a(y) , .b(16'h0000) , .sel(zy) , .out(zeroed_y) );
    // if (ny == 1) sets y = !y       // bitwise not
    not16 negate_y (.in(zeroed_y) , .out(negated_y) );
    mux16 ny_select (.a(zeroed_y) , .b(negated_y) , .sel(ny) , .out(arbitrated_y) );

    /* perform the function on inputs */
    // if (f == 1)  sets out = x + y  // integer 2's complement addition
    add16 add_xy (.a(arbitrated_x) , .b(arbitrated_y) , .out(x_added_y) );
    and16 and_xy (.a(arbitrated_x) , .b(arbitrated_y) , .out(x_and_y) );
    mux16 f_select (.a(x_and_y) , .b(x_added_y) , .sel(f) , .out(function_out) );   

    /* conditon the output (optional negation) */
    not16 negate_out (.in(function_out) , .out(negated_out) );
    mux16 no_select (.a(function_out) , .b(negated_out) , .sel(no) , .out(out) ); 
    assign ng = out[15]; 
    
    /* check for negative or zero */
    or8way lower_bits (.in(out[7:0]) , .out(lower_any) );
    or8way upper_bits (.in(out[15:8]) , .out(upper_any) );
    or_gate combine_flags (.a(lower_any), .b(upper_any) , .out(any_set) );
    not_gate zr_set (.in(any_set), .out(zr) );

endmodule
