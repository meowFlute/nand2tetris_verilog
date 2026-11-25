`timescale 1ns / 1ps

module test_dmux4way;
    // test signals
    reg test_in;
    reg [1:0] test_sel;
    wire test_a;
    wire test_b;
    wire test_c;
    wire test_d;
    reg error_occurred = 0;

    // instantiate the device under test and wire it to the bench signals
    dmux4way dut (
        .in(test_in),
        .sel(test_sel),
        .a(test_a),
        .b(test_b),
        .c(test_c),
        .d(test_d)
    );

    // reusable task for each test case
    task check_case;
        input in_val;
        input [1:0] sel_val;
        input expected_a;
        input expected_b;
        input expected_c;
        input expected_d;
        begin
            test_in = in_val;
            test_sel = sel_val;
            #10;

            $display("%4t | %b | %b | %b | %b | %b | %b", $time, test_in, test_sel, test_a, test_b, test_c, test_d);
            if (test_a !== expected_a || test_b !== expected_b || test_c !== expected_c || test_d !== expected_d) begin
                $display("[FAIL] in: %b | sel: %b | Expected a: %b | Got: %b | Expected b: %b | Got: %b | Expected c: %b | Got: %b | Expected d: %b | Got: %b", test_in, test_sel, expected_a, test_a, expected_b, test_b, expected_c, test_c, expected_d, test_d);
                error_occurred = 1;
            end
        end
    endtask

    // actual code running the tasks to do the test cases
    initial begin
        // Print the header for the results table
        $display("Time | in | sel | a | b | c | d");
        $display("-------------------------------");

        // Fill in inputs and expected outputs for each case
        /*
        | 1'b0, 2'b00, 1'b0, 1'b0, 1'b0, 1'b0 |
        | 1'b0, 2'b01, 1'b0, 1'b0, 1'b0, 1'b0 |
        | 1'b0, 2'b10, 1'b0, 1'b0, 1'b0, 1'b0 |
        | 1'b0, 2'b11, 1'b0, 1'b0, 1'b0, 1'b0 |
        | 1'b1, 2'b00, 1'b1, 1'b0, 1'b0, 1'b0 |
        | 1'b1, 2'b01, 1'b0, 1'b1, 1'b0, 1'b0 |
        | 1'b1, 2'b10, 1'b0, 1'b0, 1'b1, 1'b0 |
        | 1'b1, 2'b11, 1'b0, 1'b0, 1'b0, 1'b1 |
        */
        check_case(1'b0, 2'b00, 1'b0, 1'b0, 1'b0, 1'b0); // Test case 1
        check_case(1'b0, 2'b01, 1'b0, 1'b0, 1'b0, 1'b0); // Test case 2
        check_case(1'b0, 2'b10, 1'b0, 1'b0, 1'b0, 1'b0); // Test case 3
        check_case(1'b0, 2'b11, 1'b0, 1'b0, 1'b0, 1'b0); // Test case 4
        check_case(1'b1, 2'b00, 1'b1, 1'b0, 1'b0, 1'b0); // Test case 5
        check_case(1'b1, 2'b01, 1'b0, 1'b1, 1'b0, 1'b0); // Test case 6
        check_case(1'b1, 2'b10, 1'b0, 1'b0, 1'b1, 1'b0); // Test case 7
        check_case(1'b1, 2'b11, 1'b0, 1'b0, 1'b0, 1'b1); // Test case 8

        if (error_occurred) begin
            $display("--> DMUX4WAY TEST: FAILED");
            $finish(1);
        end else begin
            $display("--> DMUX4WAY TEST: PASSED");
            $finish(0);
        end
    end
endmodule
