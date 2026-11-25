`timescale 1ns / 1ps

module test_dff;
    // test signals
    reg test_clk;
    reg test_in;
    wire test_out;
    reg error_occurred = 0;

    // instantiate the device under test and wire it to the bench signals
    dff dut (
        .clk(test_clk),
        .in(test_in),
        .out(test_out)
    );

    // one full clock cycle: set up inputs, rising edge, check, perturb, check, fall
    task tick_and_check;
        input in_val;
        input expected_out;
        begin
            // Set up data while clock is low
            test_clk = 1'b0;
            test_in = in_val;
            #5;
            $display("%0t | %b | %b | %b", $time, test_clk, test_in, test_out);

            // Rising clock edge captures the inputs
            test_clk = 1'b1;
            #1;
            $display("%0t | %b | %b | %b", $time, test_clk, test_in, test_out);
            if (test_out !== expected_out) begin
                $display("[FAIL @ %0t] after posedge: in=%b expected_out=%b got=%b",
                         $time, test_in, expected_out, test_out);
                error_occurred = 1;
            end

            // Mutate inputs while clock is high; outputs must hold
            #4;
            $display("%0t | %b | %b | %b", $time, test_clk, test_in, test_out);
            test_in = ~in_val;
            #2;
            $display("%0t | %b | %b | %b", $time, test_clk, test_in, test_out);
            if (test_out !== expected_out) begin
                $display("[FAIL @ %0t] during clk=1 hold: in=%b expected_out=%b got=%b",
                         $time, test_in, expected_out, test_out);
                error_occurred = 1;
            end

            // Return clock low
            test_clk = 1'b0;
            #3;
            $display("%0t | %b | %b | %b", $time, test_clk, test_in, test_out);
        end
    endtask

    // actual code running the tasks to do the test cases
    initial begin
        $timeformat(-9, 0, " ns", 8);
        // Print the header for the results table
        $display("Time | clk | in | out");
        $display("---------------------");
        test_clk = 1'b0;
        test_in = 1'd0;
        #5;
        $display("%0t | %b | %b | %b", $time, test_clk, test_in, test_out);

        // Fill in one call per clock cycle: tick_and_check(in, expected_out)
        // Outputs are X until the first edge, and state carries over between calls.
        tick_and_check(1'b0, 1'b0); // Cycle 1
        tick_and_check(1'b1, 1'b1); // Cycle 2
        tick_and_check(1'b1, 1'b1); // Cycle 3
        tick_and_check(1'b0, 1'b0); // Cycle 4

        if (error_occurred) begin
            $display("--> DFF TEST: FAILED");
            $finish(1);
        end else begin
            $display("--> DFF TEST: PASSED");
            $finish(0);
        end
    end
endmodule
