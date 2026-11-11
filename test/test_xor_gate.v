`timescale 1ns / 1ps

module test_xor_gate;
    // test signals
    reg test_a;
    reg test_b;
    wire test_out;
    reg error_occurred = 0;

    // instantiate the device under test and wire it to the bench signals
    xor_gate dut (
        .a(test_a),
        .b(test_b),
        .out(test_out)
    );

    // reusable task for each test case
    task check_case;
        input a_val;
        input b_val;
        input expected_out;
        begin
            test_a = a_val;
            test_b = b_val;
            #10;

            $display("%4t | %b | %b | %b", $time, test_a, test_b, test_out);
            if (test_out !== expected_out) begin
                $display("[FAIL] a: %b | b: %b | Expected out: %b | Got: %b", test_a, test_b, expected_out, test_out);
                error_occurred = 1;
            end
        end
    endtask

    // actual code running the tasks to do the test cases
    initial begin
        // Print the header for the results table
        $display("Time | a | b | out");
        $display("------------------");

        // Fill in expected outputs for all 4 input combinations
        check_case(1'b0, 1'b0, 1'b0); // Test case 1: 0, 0 -> 0
        check_case(1'b0, 1'b1, 1'b1); // Test case 2: 0, 1 -> 1
        check_case(1'b1, 1'b0, 1'b1); // Test case 3: 1, 0 -> 1
        check_case(1'b1, 1'b1, 1'b0); // Test case 4: 1, 1 -> 0

        if (error_occurred) begin
            $display("--> XOR GATE TEST: FAILED");
            $finish(1);
        end else begin
            $display("--> XOR GATE TEST: PASSED");
            $finish(0);
        end
    end
endmodule
