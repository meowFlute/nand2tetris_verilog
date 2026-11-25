`timescale 1ns / 1ps

module test_inc16;
    // test signals
    reg [15:0] test_in;
    wire [15:0] test_out;
    reg error_occurred = 0;

    // instantiate the device under test and wire it to the bench signals
    inc16 dut (
        .in(test_in),
        .out(test_out)
    );

    // reusable task for each test case
    task check_case;
        input [15:0] in_val;
        input [15:0] expected_out;
        begin
            test_in = in_val;
            #10;

            $display("%0t | %h | %h", $time, test_in, test_out);
            if (test_out !== expected_out) begin
                $display("[FAIL @ %0t] in: %h | Expected out: %h | Got: %h", $time, test_in, expected_out, test_out);
                error_occurred = 1;
            end
        end
    endtask

    // actual code running the tasks to do the test cases
    initial begin
        $timeformat(-9, 0, " ns", 8);
        // Print the header for the results table
        $display("Time | in | out");
        $display("---------------");

        // Fill in inputs and expected outputs for each case
        /*
            |        in        |       out        |
            | 16'b0000000000000000, 16'b0000000000000001 |
            | 16'b1111111111111111, 16'b0000000000000000 |
            | 16'b0000000000000101, 16'b0000000000000110 |
            | 16'b1111111111111011, 16'b1111111111111100 |
        */ 
        check_case(16'b0000000000000000, 16'b0000000000000001); // Test case 1
        check_case(16'b1111111111111111, 16'b0000000000000000); // Test case 2
        check_case(16'b0000000000000101, 16'b0000000000000110); // Test case 3
        check_case(16'b1111111111111011, 16'b1111111111111100); // Test case 4

        if (error_occurred) begin
            $display("--> INC16 TEST: FAILED");
            $finish(1);
        end else begin
            $display("--> INC16 TEST: PASSED");
            $finish(0);
        end
    end
endmodule
