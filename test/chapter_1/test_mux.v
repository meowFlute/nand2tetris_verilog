`timescale 1ns / 1ps

module test_mux;
    // test signals
    reg test_a;
    reg test_b;
    reg test_sel;
    wire test_out;
    reg error_occurred = 0;

    // instantiate the device under test and wire it to the bench signals
    mux dut (
        .a(test_a),
        .b(test_b),
        .sel(test_sel),
        .out(test_out)
    );

    // reusable task for each test case
    task check_case;
        input a_val;
        input b_val;
        input sel_val;
        input expected_out;
        begin
            test_a = a_val;
            test_b = b_val;
            test_sel = sel_val;
            #10;

            $display("%4t | %b | %b | %b | %b", $time, test_a, test_b, test_sel, test_out);
            if (test_out !== expected_out) begin
                $display("[FAIL] a: %b | b: %b | sel: %b | Expected out: %b | Got: %b", test_a, test_b, test_sel, expected_out, test_out);
                error_occurred = 1;
            end
        end
    endtask

    // actual code running the tasks to do the test cases
    initial begin
        // Print the header for the results table
        $display("Time | a | b | sel | out");
        $display("------------------------");

        // Fill in expected outputs for all 8 input combinations
        check_case(1'b0, 1'b0, 1'b0, 1'b0); // Test case 1: 0, 0, 0 -> 0
        check_case(1'b0, 1'b0, 1'b1, 1'b0); // Test case 2: 0, 0, 1 -> 0
        check_case(1'b0, 1'b1, 1'b0, 1'b0); // Test case 3: 0, 1, 0 -> 0
        check_case(1'b0, 1'b1, 1'b1, 1'b1); // Test case 4: 0, 1, 1 -> 1
        check_case(1'b1, 1'b0, 1'b0, 1'b1); // Test case 5: 1, 0, 0 -> 1
        check_case(1'b1, 1'b0, 1'b1, 1'b0); // Test case 6: 1, 0, 1 -> 0
        check_case(1'b1, 1'b1, 1'b0, 1'b1); // Test case 7: 1, 1, 0 -> 1
        check_case(1'b1, 1'b1, 1'b1, 1'b1); // Test case 8: 1, 1, 1 -> 1

        if (error_occurred) begin
            $display("--> MUX TEST: FAILED");
            $finish(1);
        end else begin
            $display("--> MUX TEST: PASSED");
            $finish(0);
        end
    end
endmodule
