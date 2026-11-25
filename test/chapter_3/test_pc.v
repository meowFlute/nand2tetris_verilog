`timescale 1ns / 1ps

module test_pc;
    // test signals
    reg test_clk;
    reg [15:0] test_in;
    reg test_inc;
    reg test_load;
    reg test_reset;
    wire [15:0] test_out;
    reg error_occurred = 0;
    // last output values we verified; outputs must not move before the next edge
    reg [15:0] prev_out;

    // instantiate the device under test and wire it to the bench signals
    pc dut (
        .clk(test_clk),
        .in(test_in),
        .inc(test_inc),
        .load(test_load),
        .reset(test_reset),
        .out(test_out)
    );

    // one full clock cycle: set up inputs, rising edge, check, perturb, check, fall
    task tick_and_check;
        input [15:0] in_val;
        input inc_val;
        input load_val;
        input reset_val;
        input [15:0] expected_out;
        begin
            // Set up data while clock is low
            test_clk = 1'b0;
            test_in = in_val;
            test_inc = inc_val;
            test_load = load_val;
            test_reset = reset_val;
            #5;
            $display("%0t | %b | %h | %b | %b | %b | %h", $time, test_clk, test_in, test_inc, test_load, test_reset, test_out);
            // Outputs must still hold the previous state: no edge has happened yet
            if (test_out !== prev_out) begin
                $display("[FAIL @ %0t] before posedge: in=%h inc=%b load=%b reset=%b prev_out=%h got=%h",
                         $time, test_in, test_inc, test_load, test_reset, prev_out, test_out);
                error_occurred = 1;
            end

            // Rising clock edge captures the inputs
            test_clk = 1'b1;
            #1;
            $display("%0t | %b | %h | %b | %b | %b | %h", $time, test_clk, test_in, test_inc, test_load, test_reset, test_out);
            if (test_out !== expected_out) begin
                $display("[FAIL @ %0t] after posedge: in=%h inc=%b load=%b reset=%b expected_out=%h got=%h",
                         $time, test_in, test_inc, test_load, test_reset, expected_out, test_out);
                error_occurred = 1;
            end

            // Mutate inputs while clock is high; outputs must hold
            #4;
            $display("%0t | %b | %h | %b | %b | %b | %h", $time, test_clk, test_in, test_inc, test_load, test_reset, test_out);
            test_in = ~in_val;
            test_inc = ~inc_val;
            test_load = ~load_val;
            test_reset = ~reset_val;
            #2;
            $display("%0t | %b | %h | %b | %b | %b | %h", $time, test_clk, test_in, test_inc, test_load, test_reset, test_out);
            if (test_out !== expected_out) begin
                $display("[FAIL @ %0t] during clk=1 hold: in=%h inc=%b load=%b reset=%b expected_out=%h got=%h",
                         $time, test_in, test_inc, test_load, test_reset, expected_out, test_out);
                error_occurred = 1;
            end

            // Return clock low
            test_clk = 1'b0;
            #3;
            $display("%0t | %b | %h | %b | %b | %b | %h", $time, test_clk, test_in, test_inc, test_load, test_reset, test_out);

            prev_out = expected_out;
        end
    endtask

    // actual code running the tasks to do the test cases
    initial begin
        $timeformat(-9, 0, " ns", 8);
        // Print the header for the results table
        $display("Time | clk | in | inc | load | reset | out");
        $display("------------------------------------------");
        test_clk = 1'b0;
        test_in = 16'd0;
        test_inc = 1'd0;
        test_load = 1'd0;
        test_reset = 1'd0;
        #5;
        $display("%0t | %b | %h | %b | %b | %b | %h", $time, test_clk, test_in, test_inc, test_load, test_reset, test_out);
        // Whatever the power-up value is (X or 0), treat it as the baseline
        prev_out = test_out;

        // Fill in one call per clock cycle: tick_and_check(in, inc, load, reset, expected_out)
        // Outputs are X until the first edge, and state carries over between calls.

        // Phase 1: reset from power-up, count, hold
        tick_and_check(16'h0000, 1'b0, 1'b0, 1'b1, 16'h0000); // Cycle 1: reset clears the X state
        tick_and_check(16'h0000, 1'b1, 1'b0, 1'b0, 16'h0001); // Cycle 2: inc
        tick_and_check(16'h0000, 1'b1, 1'b0, 1'b0, 16'h0002); // Cycle 3
        tick_and_check(16'h0000, 1'b1, 1'b0, 1'b0, 16'h0003); // Cycle 4
        tick_and_check(16'hffff, 1'b0, 1'b0, 1'b0, 16'h0003); // Cycle 5: hold, junk on in
        tick_and_check(16'hffff, 1'b0, 1'b0, 1'b0, 16'h0003); // Cycle 6: still holding

        // Phase 2: load, then increment from the loaded value
        tick_and_check(16'h1234, 1'b0, 1'b1, 1'b0, 16'h1234); // Cycle 7
        tick_and_check(16'h0000, 1'b1, 1'b0, 1'b0, 16'h1235); // Cycle 8
        tick_and_check(16'hffff, 1'b0, 1'b1, 1'b0, 16'hffff); // Cycle 9
        tick_and_check(16'h0000, 1'b1, 1'b0, 1'b0, 16'h0000); // Cycle 10: wraps around
        tick_and_check(16'h0000, 1'b1, 1'b0, 1'b0, 16'h0001); // Cycle 11

        // Phase 3: carry chains (nibble, byte, all the way to bit 15)
        tick_and_check(16'h000f, 1'b0, 1'b1, 1'b0, 16'h000f); // Cycle 12
        tick_and_check(16'h0000, 1'b1, 1'b0, 1'b0, 16'h0010); // Cycle 13: nibble carry
        tick_and_check(16'h00ff, 1'b0, 1'b1, 1'b0, 16'h00ff); // Cycle 14
        tick_and_check(16'h0000, 1'b1, 1'b0, 1'b0, 16'h0100); // Cycle 15: byte carry
        tick_and_check(16'h7fff, 1'b0, 1'b1, 1'b0, 16'h7fff); // Cycle 16
        tick_and_check(16'h0000, 1'b1, 1'b0, 1'b0, 16'h8000); // Cycle 17: carry into bit 15
        tick_and_check(16'h0fff, 1'b0, 1'b1, 1'b0, 16'h0fff); // Cycle 18
        tick_and_check(16'h0000, 1'b1, 1'b0, 1'b0, 16'h1000); // Cycle 19: 12-bit carry

        // Phase 4: control priority (reset > load > inc)
        tick_and_check(16'habcd, 1'b1, 1'b1, 1'b1, 16'h0000); // Cycle 20: all three asserted -> reset
        tick_and_check(16'h0000, 1'b1, 1'b0, 1'b0, 16'h0001); // Cycle 21
        tick_and_check(16'h5a5a, 1'b1, 1'b1, 1'b0, 16'h5a5a); // Cycle 22: load beats inc
        tick_and_check(16'hffff, 1'b0, 1'b1, 1'b1, 16'h0000); // Cycle 23: reset beats load
        tick_and_check(16'hffff, 1'b0, 1'b0, 1'b0, 16'h0000); // Cycle 24: hold at 0
        tick_and_check(16'h0000, 1'b1, 1'b0, 1'b0, 16'h0001); // Cycle 25
        tick_and_check(16'h0000, 1'b1, 1'b0, 1'b1, 16'h0000); // Cycle 26: reset beats inc

        // Phase 5: load a value, hold it with a zero input, increment across a nibble, reset
        tick_and_check(16'hbeef, 1'b0, 1'b1, 1'b0, 16'hbeef); // Cycle 27
        tick_and_check(16'h0000, 1'b0, 1'b0, 1'b0, 16'hbeef); // Cycle 28: hold
        tick_and_check(16'h0000, 1'b1, 1'b0, 1'b0, 16'hbef0); // Cycle 29: 0xbeef + 1
        tick_and_check(16'hffff, 1'b0, 1'b0, 1'b1, 16'h0000); // Cycle 30: reset with junk on in

        if (error_occurred) begin
            $display("--> PC TEST: FAILED");
            $finish(1);
        end else begin
            $display("--> PC TEST: PASSED");
            $finish(0);
        end
    end
endmodule
