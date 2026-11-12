`timescale 1ns / 1ps

module test_or8way;
    // test signals
    reg [7:0] test_in;
    wire test_out;
    reg error_occurred = 0;

    // instantiate the device under test and wire it to the bench signals
    or8way dut (
        .in(test_in),
        .out(test_out)
    );

    // reusable task for each test case
    task check_case;
        input [7:0] in_val;
        input expected_out;
        begin
            test_in = in_val;
            #10;

            $display("%4t | %h | %b", $time, test_in, test_out);
            if (test_out !== expected_out) begin
                $display("[FAIL] in: %h | Expected out: %b | Got: %b", test_in, expected_out, test_out);
                error_occurred = 1;
            end
        end
    endtask

    // actual code running the tasks to do the test cases
    initial begin
        // Print the header for the results table
        $display("Time | in | out");
        $display("---------------");

        // Fill in inputs and expected outputs for each case
        /* test cases
        |     in      ,  out |
        |  8'b00000000, 1'b0 |
        |  8'b11111111, 1'b1 |
        |  8'b00010000, 1'b1 |
        |  8'b00000001, 1'b1 |
        |  8'b00100110, 1'b1 |
        */
        check_case(8'b00000000, 1'b0); // Test case 1
        check_case(8'b11111111, 1'b1); // Test case 2
        check_case(8'b00010000, 1'b1); // Test case 3
        check_case(8'b00000001, 1'b1); // Test case 4
        check_case(8'b00100110, 1'b1); // Test case 5

        if (error_occurred) begin
            $display("--> OR8WAY TEST: FAILED");
            $finish(1);
        end else begin
            $display("--> OR8WAY TEST: PASSED");
            $finish(0);
        end
    end
endmodule
