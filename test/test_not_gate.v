`timescale 1ns / 1ps

module tb_not_gate;
	// test signals
	reg tb_in;
	wire tb_out;
	reg error_occurred = 0;

	// instantiate the not gate from my library and wire it to the bench
	// signals
	not_gate uut (
		.in(tb_in),
		.out(tb_out)
	);

	initial begin
		// Print the header for the truth table
		$display("Time | in | out");
		$display("---------------");

		// Test case 1: input 0 (output should be 1)
		tb_in = 1'b0;
		#10
		$display("%4t | %b | %b", $time, tb_in, tb_out);
		if (tb_out !== 1'b1) begin
			$display("[FAIL] In: 0 | Expected: 1 | Got: %b", tb_out);
			error_occurred = 1;
		end

		// Test case 2: input 1 (output should be 0)
		tb_in = 1'b1;
		#10
		$display("%4t | %b | %b", $time, tb_in, tb_out);
		if (tb_out !== 1'b0) begin
			$display("[FAIL] In: 1 | Expected: 0 | Got: %b", tb_out);
			error_occurred = 1;
		end

		if (error_occurred) begin
			$display("--> NOT GATE TEST: FAILED");
			$finish(1);
		end else begin
			$display("--> NOT GATE TEST: PASSED");
			$finish(0);
		end
	end
endmodule
