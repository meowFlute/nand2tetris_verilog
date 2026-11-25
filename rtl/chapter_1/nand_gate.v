(* blackbox *)
module nand_gate (
    input  wire a,
    input  wire b,
    output wire out
);
    // Instantiates Verilog's built-in primitive gate inside the blackbox boundary
    nand primitive_nand (out, a, b);

endmodule
