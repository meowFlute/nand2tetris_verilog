`timescale 1ns / 1ps

module test_or16;
    // test signals
    reg [15:0] test_a;
    reg [15:0] test_b;
    wire [15:0] test_out;
    reg error_occurred = 0;

    // instantiate the device under test and wire it to the bench signals
    or16 dut (
        .a(test_a),
        .b(test_b),
        .out(test_out)
    );

    // reusable task for each test case
    task check_case;
        input [15:0] a_val;
        input [15:0] b_val;
        input [15:0] expected_out;
        begin
            test_a = a_val;
            test_b = b_val;
            #10;

            $display("%4t | %h | %h | %h", $time, test_a, test_b, test_out);
            if (test_out !== expected_out) begin
                $display("[FAIL] a: %h | b: %h | Expected out: %h | Got: %h", test_a, test_b, expected_out, test_out);
                error_occurred = 1;
            end
        end
    endtask

    // actual code running the tasks to do the test cases
    initial begin
        // Print the header for the results table
        $display("Time | a | b | out");
        $display("------------------");

        // Fill in inputs and expected outputs for each case
        /* test cases
        |        a            |        b            |       out            |
        | 16'b0000000000000000, 16'b0000000000000000, 16'b0000000000000000 |
        | 16'b0000000000000000, 16'b1111111111111111, 16'b1111111111111111 |
        | 16'b1111111111111111, 16'b1111111111111111, 16'b1111111111111111 |
        | 16'b1010101010101010, 16'b0101010101010101, 16'b1111111111111111 |
        | 16'b0011110011000011, 16'b0000111111110000, 16'b0011111111110011 |
        | 16'b0001001000110100, 16'b1001100001110110, 16'b1001101001110110 |
        */
        check_case(16'b0000000000000000, 16'b0000000000000000, 16'b0000000000000000); // Test case 1
        check_case(16'b0000000000000000, 16'b1111111111111111, 16'b1111111111111111); // Test case 2
        check_case(16'b1111111111111111, 16'b1111111111111111, 16'b1111111111111111); // Test case 3
        check_case(16'b1010101010101010, 16'b0101010101010101, 16'b1111111111111111); // Test case 4
        check_case(16'b0011110011000011, 16'b0000111111110000, 16'b0011111111110011); // Test case 5
        check_case(16'b0001001000110100, 16'b1001100001110110, 16'b1001101001110110); // Test case 6

        if (error_occurred) begin
            $display("--> OR16 TEST: FAILED");
            $finish(1);
        end else begin
            $display("--> OR16 TEST: PASSED");
            $finish(0);
        end
    end
endmodule
