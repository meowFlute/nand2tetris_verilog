`timescale 1ns / 1ps

module test_full_adder;
    // test signals
    reg test_a;
    reg test_b;
    reg test_c;
    wire test_sum;
    wire test_carry;
    reg error_occurred = 0;

    // instantiate the device under test and wire it to the bench signals
    full_adder dut (
        .a(test_a),
        .b(test_b),
        .c(test_c),
        .sum(test_sum),
        .carry(test_carry)
    );

    // reusable task for each test case
    task check_case;
        input a_val;
        input b_val;
        input c_val;
        input expected_sum;
        input expected_carry;
        begin
            test_a = a_val;
            test_b = b_val;
            test_c = c_val;
            #10;

            $display("%4t | %b | %b | %b | %b | %b", $time, test_a, test_b, test_c, test_sum, test_carry);
            if (test_sum !== expected_sum || test_carry !== expected_carry) begin
                $display("[FAIL] a: %b | b: %b | c: %b | Expected sum: %b | Got: %b | Expected carry: %b | Got: %b", test_a, test_b, test_c, expected_sum, test_sum, expected_carry, test_carry);
                error_occurred = 1;
            end
        end
    endtask

    // actual code running the tasks to do the test cases
    initial begin
        // Print the header for the results table
        $display("Time | a | b | c | sum | carry");
        $display("------------------------------");

        // Fill in expected outputs for all 8 input combinations
        check_case(1'b0, 1'b0, 1'b0, 1'b0, 1'b0); // Test case 1: 0, 0, 0->0,0
        check_case(1'b0, 1'b0, 1'b1, 1'b1, 1'b0); // Test case 2: 0, 0, 1->1,0
        check_case(1'b0, 1'b1, 1'b0, 1'b1, 1'b0); // Test case 3: 0, 1, 0->1,0
        check_case(1'b0, 1'b1, 1'b1, 1'b0, 1'b1); // Test case 4: 0, 1, 1->0,1
        check_case(1'b1, 1'b0, 1'b0, 1'b1, 1'b0); // Test case 5: 1, 0, 0->1,0
        check_case(1'b1, 1'b0, 1'b1, 1'b0, 1'b1); // Test case 6: 1, 0, 1->0,1
        check_case(1'b1, 1'b1, 1'b0, 1'b0, 1'b1); // Test case 7: 1, 1, 0->0,1
        check_case(1'b1, 1'b1, 1'b1, 1'b1, 1'b1); // Test case 8: 1, 1, 1->1,1

        if (error_occurred) begin
            $display("--> FULL ADDER TEST: FAILED");
            $finish(1);
        end else begin
            $display("--> FULL ADDER TEST: PASSED");
            $finish(0);
        end
    end
endmodule
