`timescale 1ns / 1ps

module test_mux16;
    // test signals
    reg [15:0] test_a;
    reg [15:0] test_b;
    reg test_sel;
    wire [15:0] test_out;
    reg error_occurred = 0;

    // instantiate the device under test and wire it to the bench signals
    mux16 dut (
        .a(test_a),
        .b(test_b),
        .sel(test_sel),
        .out(test_out)
    );

    // reusable task for each test case
    task check_case;
        input [15:0] a_val;
        input [15:0] b_val;
        input sel_val;
        input [15:0] expected_out;
        begin
            test_a = a_val;
            test_b = b_val;
            test_sel = sel_val;
            #10;

            $display("%4t | %h | %h | %b | %h", $time, test_a, test_b, test_sel, test_out);
            if (test_out !== expected_out) begin
                $display("[FAIL] a: %h | b: %h | sel: %b | Expected out: %h | Got: %h", test_a, test_b, test_sel, expected_out, test_out);
                error_occurred = 1;
            end
        end
    endtask

    // actual code running the tasks to do the test cases
    initial begin
        // Print the header for the results table
        $display("Time | a | b | sel | out");
        $display("------------------------");

        // Fill in inputs and expected outputs for each case
        /* TEST CASES
        |        a         |        b         |sel|       out        |
        | 16'b0000000000000000, 16'b0000000000000000, 1'b0, 16'b0000000000000000 |
        | 16'b0000000000000000, 16'b0000000000000000, 1'b1, 16'b0000000000000000 |
        | 16'b0000000000000000, 16'b0001001000110100, 1'b0, 16'b0000000000000000 |
        | 16'b0000000000000000, 16'b0001001000110100, 1'b1, 16'b0001001000110100 |
        | 16'b1001100001110110, 16'b0000000000000000, 1'b0, 16'b1001100001110110 |
        | 16'b1001100001110110, 16'b0000000000000000, 1'b1, 16'b0000000000000000 |
        | 16'b1010101010101010, 16'b0101010101010101, 1'b0, 16'b1010101010101010 |
        | 16'b1010101010101010, 16'b0101010101010101, 1'b1, 16'b0101010101010101 |
        */
        check_case(16'b0000000000000000, 16'b0000000000000000, 1'b0, 16'b0000000000000000); // Test case 1
        check_case(16'b0000000000000000, 16'b0000000000000000, 1'b1, 16'b0000000000000000); // Test case 2
        check_case(16'b0000000000000000, 16'b0001001000110100, 1'b0, 16'b0000000000000000); // Test case 3
        check_case(16'b0000000000000000, 16'b0001001000110100, 1'b1, 16'b0001001000110100); // Test case 4
        check_case(16'b1001100001110110, 16'b0000000000000000, 1'b0, 16'b1001100001110110); // Test case 5
        check_case(16'b1001100001110110, 16'b0000000000000000, 1'b1, 16'b0000000000000000); // Test case 6
        check_case(16'b1010101010101010, 16'b0101010101010101, 1'b0, 16'b1010101010101010); // Test case 7
        check_case(16'b1010101010101010, 16'b0101010101010101, 1'b1, 16'b0101010101010101); // Test case 8

        if (error_occurred) begin
            $display("--> MUX16 TEST: FAILED");
            $finish(1);
        end else begin
            $display("--> MUX16 TEST: PASSED");
            $finish(0);
        end
    end
endmodule
