module and_gate (
	input  wire a,
	input  wire b,
	output wire out
);
	// do an nand and negate the output
	wire internal_nand_out;
	
	nand_gate primitive_nand (.out(internal_nand_out), .a(a), .b(b));

	not_gate derived_not (
		.in(internal_nand_out),
		.out(out)
	);

endmodule
