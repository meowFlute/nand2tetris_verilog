`timescale 1ns / 1ps

module test_not_gate;
	// test signals
	reg test_a;
	reg test_b;
	wire test_out;
	reg error_occurred = 0;

	// instantiate the not gate from my library and wire it to the bench
	// signals
	and_gate test_and (
		.a(test_a),
		.b(test_b),
		.out(test_out)
	);

	// reusable task for each test case
    	task check_case;
        	input reg a_val;
        	input reg b_val;
        	input reg expected_val;
        	begin
            		test_a = a_val;
            		test_b = b_val;
            		#10;
            
            		$display("%4t | %b | %b | %b", $time, test_a, test_b, test_out);
            		if (test_out !== expected_val) begin
                		$display("[FAIL] A: %b | B: %b | Expected: %b | Got: %b", test_a, test_b, expected_val, test_out);
                		error_occurred = 1;
            		end
        	end
    	endtask

	// actual code running the tasks to do the test cases
	initial begin
		// Print the header for the truth table
		$display("Time | a | b | out");
		$display("------------------");

		// Call the task for all 4 truth-table combinations of an AND gate
        	check_case(1'b0, 1'b0, 1'b0); // Test case 1: 0, 0 -> 0
        	check_case(1'b0, 1'b1, 1'b0); // Test case 2: 0, 1 -> 0
        	check_case(1'b1, 1'b0, 1'b0); // Test case 3: 1, 0 -> 0
        	check_case(1'b1, 1'b1, 1'b1); // Test case 4: 1, 1 -> 1

		if (error_occurred) begin
			$display("--> AND GATE TEST: FAILED");
			$finish(1);
		end else begin
			$display("--> AND GATE TEST: PASSED");
			$finish(0);
		end
	end
endmodule
