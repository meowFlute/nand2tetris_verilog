`timescale 1ns / 1ps

module test_half_adder;
    // test signals
    reg test_a;
    reg test_b;
    wire test_sum;
    wire test_carry;
    reg error_occurred = 0;

    // instantiate the device under test and wire it to the bench signals
    half_adder dut (
        .a(test_a),
        .b(test_b),
        .sum(test_sum),
        .carry(test_carry)
    );

    // reusable task for each test case
    task check_case;
        input a_val;
        input b_val;
        input expected_sum;
        input expected_carry;
        begin
            test_a = a_val;
            test_b = b_val;
            #10;

            $display("%0t | %b | %b | %b | %b", $time, test_a, test_b, test_sum, test_carry);
            if (test_sum !== expected_sum || test_carry !== expected_carry) begin
                $display("[FAIL @ %0t] a: %b | b: %b | Expected sum: %b | Got: %b | Expected carry: %b | Got: %b", $time, test_a, test_b, expected_sum, test_sum, expected_carry, test_carry);
                error_occurred = 1;
            end
        end
    endtask

    // actual code running the tasks to do the test cases
    initial begin
        $timeformat(-9, 0, " ns", 8);
        // Print the header for the results table
        $display("Time | a | b | sum | carry");
        $display("--------------------------");

        // Fill in expected outputs for all 4 input combinations
        check_case(1'b0, 1'b0, 1'b0, 1'b0); // Test case 1: 0, 0 -> 0, 0
        check_case(1'b0, 1'b1, 1'b1, 1'b0); // Test case 2: 0, 1 -> 1, 0
        check_case(1'b1, 1'b0, 1'b1, 1'b0); // Test case 3: 1, 0 -> 1, 0
        check_case(1'b1, 1'b1, 1'b0, 1'b1); // Test case 4: 1, 1 -> 0, 1 

        if (error_occurred) begin
            $display("--> HALF ADDER TEST: FAILED");
            $finish(1);
        end else begin
            $display("--> HALF ADDER TEST: PASSED");
            $finish(0);
        end
    end
endmodule
