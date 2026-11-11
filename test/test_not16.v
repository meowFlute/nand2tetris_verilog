`timescale 1ns / 1ps

module test_not16;
    // test signals
    reg [15:0] test_in;
    wire [15:0] test_out;
    reg error_occurred = 0;

    // instantiate the device under test and wire it to the bench signals
    not16 dut (
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

            $display("%4t | %h | %h", $time, test_in, test_out);
            if (test_out !== expected_out) begin
                $display("[FAIL] in: %h | Expected out: %h | Got: %h", test_in, expected_out, test_out);
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
        check_case(16'b0000_0000_0000_0000, 16'b1111_1111_1111_1111); // Test case 1 | 0000000000000000 | 1111111111111111 |
        check_case(16'b1111_1111_1111_1111, 16'b0000_0000_0000_0000); // Test case 2 | 1111111111111111 | 0000000000000000 |
        check_case(16'b1010_1010_1010_1010, 16'b0101_0101_0101_0101); // Test case 3 | 1010101010101010 | 0101010101010101 |
        check_case(16'b0011_1100_1100_0011, 16'b1100_0011_0011_1100); // Test case 4 | 0011110011000011 | 1100001100111100 |
        check_case(16'b0001_0010_0011_0100, 16'b1110_1101_1100_1011); // Test case 5 | 0001001000110100 | 1110110111001011 |

        if (error_occurred) begin
            $display("--> NOT16 TEST: FAILED");
            $finish(1);
        end else begin
            $display("--> NOT16 TEST: PASSED");
            $finish(0);
        end
    end
endmodule
