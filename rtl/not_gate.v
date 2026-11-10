module not_gate (
	input  wire in,
	output wire out
);

	nand_gate primitive_nand (
		in,
		in,
		out
	);

endmodule
