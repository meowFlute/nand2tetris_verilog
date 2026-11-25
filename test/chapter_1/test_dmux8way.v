`timescale 1ns / 1ps

module test_dmux8way;
    // test signals
    reg test_in;
    reg [2:0] test_sel;
    wire test_a;
    wire test_b;
    wire test_c;
    wire test_d;
    wire test_e;
    wire test_f;
    wire test_g;
    wire test_h;
    reg error_occurred = 0;

    // instantiate the device under test and wire it to the bench signals
    dmux8way dut (
        .in(test_in),
        .sel(test_sel),
        .a(test_a),
        .b(test_b),
        .c(test_c),
        .d(test_d),
        .e(test_e),
        .f(test_f),
        .g(test_g),
        .h(test_h)
    );

    // reusable task for each test case
    task check_case;
        input in_val;
        input [2:0] sel_val;
        input expected_a;
        input expected_b;
        input expected_c;
        input expected_d;
        input expected_e;
        input expected_f;
        input expected_g;
        input expected_h;
        begin
            test_in = in_val;
            test_sel = sel_val;
            #10;

            $display("%4t | %b | %b | %b | %b | %b | %b | %b | %b | %b | %b", $time, test_in, test_sel, test_a, test_b, test_c, test_d, test_e, test_f, test_g, test_h);
            if (test_a !== expected_a || test_b !== expected_b || test_c !== expected_c || test_d !== expected_d || test_e !== expected_e || test_f !== expected_f || test_g !== expected_g || test_h !== expected_h) begin
                $display("[FAIL] in: %b | sel: %b | Expected a: %b | Got: %b | Expected b: %b | Got: %b | Expected c: %b | Got: %b | Expected d: %b | Got: %b | Expected e: %b | Got: %b | Expected f: %b | Got: %b | Expected g: %b | Got: %b | Expected h: %b | Got: %b", test_in, test_sel, expected_a, test_a, expected_b, test_b, expected_c, test_c, expected_d, test_d, expected_e, test_e, expected_f, test_f, expected_g, test_g, expected_h, test_h);
                error_occurred = 1;
            end
        end
    endtask

    // actual code running the tasks to do the test cases
    initial begin
        // Print the header for the results table
        $display("Time | in | sel | a | b | c | d | e | f | g | h");
        $display("-----------------------------------------------");

        // Fill in inputs and expected outputs for each case
        /*
        | 1'b0, 3'b000, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0 |
        | 1'b0, 3'b001, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0 |
        | 1'b0, 3'b010, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0 |
        | 1'b0, 3'b011, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0 |
        | 1'b0, 3'b100, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0 |
        | 1'b0, 3'b101, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0 |
        | 1'b0, 3'b110, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0 |
        | 1'b0, 3'b111, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0 |
        | 1'b1, 3'b000, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0 |
        | 1'b1, 3'b001, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0 |
        | 1'b1, 3'b010, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0 |
        | 1'b1, 3'b011, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0 |
        | 1'b1, 3'b100, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0 |
        | 1'b1, 3'b101, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0 |
        | 1'b1, 3'b110, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0 |
        | 1'b1, 3'b111, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1 |
        */
        check_case(1'b0, 3'b000, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0); // Test case 1
        check_case(1'b0, 3'b001, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0); // Test case 2
        check_case(1'b0, 3'b010, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0); // Test case 3
        check_case(1'b0, 3'b011, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0); // Test case 4
        check_case(1'b0, 3'b100, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0); // Test case 5
        check_case(1'b0, 3'b101, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0); // Test case 6
        check_case(1'b0, 3'b110, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0); // Test case 7
        check_case(1'b0, 3'b111, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0); // Test case 8
        check_case(1'b1, 3'b000, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0); // Test case 9
        check_case(1'b1, 3'b001, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0); // Test case 10
        check_case(1'b1, 3'b010, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0); // Test case 11
        check_case(1'b1, 3'b011, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0); // Test case 12
        check_case(1'b1, 3'b100, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0); // Test case 13
        check_case(1'b1, 3'b101, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0); // Test case 14
        check_case(1'b1, 3'b110, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0); // Test case 15
        check_case(1'b1, 3'b111, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1); // Test case 16

        if (error_occurred) begin
            $display("--> DMUX8WAY TEST: FAILED");
            $finish(1);
        end else begin
            $display("--> DMUX8WAY TEST: PASSED");
            $finish(0);
        end
    end
endmodule
