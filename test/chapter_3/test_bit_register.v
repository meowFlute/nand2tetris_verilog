`timescale 1ns / 1ps

module test_bit_register;
    // test signals
    reg test_clk;
    reg test_in;
    reg test_load;
    wire test_out;
    reg error_occurred = 0;

    // instantiate the device under test and wire it to the bench signals
    bit_register dut (
        .clk(test_clk),
        .in(test_in),
        .load(test_load),
        .out(test_out)
    );

    // one full clock cycle: set up inputs, rising edge, check, perturb, check, fall
    task tick_and_check;
        input in_val;
        input load_val;
        input expected_out;
        begin
            // Set up data while clock is low
            test_clk = 1'b0;
            test_in = in_val;
            test_load = load_val;
            #5;
            $display("%0t | %b | %b | %b | %b", $time, test_clk, test_in, test_load, test_out);

            // Rising clock edge captures the inputs
            test_clk = 1'b1;
            #1;
            $display("%0t | %b | %b | %b | %b", $time, test_clk, test_in, test_load, test_out);
            if (test_out !== expected_out) begin
                $display("[FAIL @ %0t] after posedge: in=%b load=%b expected_out=%b got=%b",
                         $time, test_in, test_load, expected_out, test_out);
                error_occurred = 1;
            end

            // Mutate inputs while clock is high; outputs must hold
            #4;
            $display("%0t | %b | %b | %b | %b", $time, test_clk, test_in, test_load, test_out);
            test_in = ~in_val;
            test_load = ~load_val;
            #2;
            $display("%0t | %b | %b | %b | %b", $time, test_clk, test_in, test_load, test_out);
            if (test_out !== expected_out) begin
                $display("[FAIL @ %0t] during clk=1 hold: in=%b load=%b expected_out=%b got=%b",
                         $time, test_in, test_load, expected_out, test_out);
                error_occurred = 1;
            end

            // Return clock low
            test_clk = 1'b0;
            #3;
            $display("%0t | %b | %b | %b | %b", $time, test_clk, test_in, test_load, test_out);
        end
    endtask

    // actual code running the tasks to do the test cases
    initial begin
        $timeformat(-9, 0, " ns", 8);
        // Print the header for the results table
        $display("Time | clk | in | load | out");
        $display("----------------------------");
        test_clk = 1'b0;
        test_in = 1'd0;
        test_load = 1'd0;
        #5;
        $display("%0t | %b | %b | %b | %b", $time, test_clk, test_in, test_load, test_out);

        // Fill in one call per clock cycle: tick_and_check(in, load, expected_out)
        // Outputs are X until the first edge, and state carries over between calls.
        tick_and_check(1'b0, 1'b1, 1'b0); // Cycle 1:  init, load 0 from unknown state
        tick_and_check(1'b0, 1'b1, 1'b0); // Cycle 2:  state 0, load 0 (same value)
        tick_and_check(1'b0, 1'b0, 1'b0); // Cycle 3:  state 0, hold, in=0
        tick_and_check(1'b1, 1'b0, 1'b0); // Cycle 4:  state 0, hold, in=1 (must ignore in)
        tick_and_check(1'b1, 1'b1, 1'b1); // Cycle 5:  state 0 -> 1, load 1
        tick_and_check(1'b1, 1'b1, 1'b1); // Cycle 6:  state 1, load 1 (same value)
        tick_and_check(1'b1, 1'b0, 1'b1); // Cycle 7:  state 1, hold, in=1
        tick_and_check(1'b0, 1'b0, 1'b1); // Cycle 8:  state 1, hold, in=0 (must ignore in)
        tick_and_check(1'b0, 1'b1, 1'b0); // Cycle 9:  state 1 -> 0, load 0
        // extras: make sure it follows `in` on consecutive loads
        tick_and_check(1'b1, 1'b1, 1'b1); // Cycle 10: 0 -> 1
        tick_and_check(1'b0, 1'b1, 1'b0); // Cycle 11: 1 -> 0
        tick_and_check(1'b1, 1'b1, 1'b1); // Cycle 12: 0 -> 1

        if (error_occurred) begin
            $display("--> BIT REGISTER TEST: FAILED");
            $finish(1);
        end else begin
            $display("--> BIT REGISTER TEST: PASSED");
            $finish(0);
        end
    end
endmodule
