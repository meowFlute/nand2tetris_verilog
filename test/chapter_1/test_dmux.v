`timescale 1ns / 1ps

module test_dmux;
    // test signals
    reg test_in;
    reg test_sel;
    wire test_a;
    wire test_b;
    reg error_occurred = 0;

    // instantiate the device under test and wire it to the bench signals
    dmux dut (
        .in(test_in),
        .sel(test_sel),
        .a(test_a),
        .b(test_b)
    );

    // reusable task for each test case
    task check_case;
        input in_val;
        input sel_val;
        input expected_a;
        input expected_b;
        begin
            test_in = in_val;
            test_sel = sel_val;
            #10;

            $display("%4t | %b | %b | %b | %b", $time, test_in, test_sel, test_a, test_b);
            if (test_a !== expected_a || test_b !== expected_b) begin
                $display("[FAIL] in: %b | sel: %b | Expected a: %b | Got: %b | Expected b: %b | Got: %b", test_in, test_sel, expected_a, test_a, expected_b, test_b);
                error_occurred = 1;
            end
        end
    endtask

    // actual code running the tasks to do the test cases
    initial begin
        // Print the header for the results table
        $display("Time | in | sel | a | b");
        $display("-----------------------");

        // Fill in expected outputs for all 4 input combinations
        check_case(1'b0, 1'b0, 1'b0, 1'b0); // Test case 1: 0, 0 -> 0, 0
        check_case(1'b0, 1'b1, 1'b0, 1'b0); // Test case 2: 0, 1 -> 0, 0
        check_case(1'b1, 1'b0, 1'b1, 1'b0); // Test case 3: 1, 0 -> 1, 0
        check_case(1'b1, 1'b1, 1'b0, 1'b1); // Test case 4: 1, 1 -> 0, 1

        if (error_occurred) begin
            $display("--> DMUX TEST: FAILED");
            $finish(1);
        end else begin
            $display("--> DMUX TEST: PASSED");
            $finish(0);
        end
    end
endmodule
