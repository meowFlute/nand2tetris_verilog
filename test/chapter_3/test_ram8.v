`timescale 1ns / 1ps

module test_ram8;
    // test signals
    reg test_clk;
    reg [15:0] test_in;
    reg [2:0] test_address;
    reg test_load;
    wire [15:0] test_out;
    reg error_occurred = 0;

    // instantiate the device under test and wire it to the bench signals
    ram8 dut (
        .clk(test_clk),
        .in(test_in),
        .address(test_address),
        .load(test_load),
        .out(test_out)
    );

    // one full clock cycle: set up inputs, rising edge, check, perturb, check, fall
    task tick_and_check;
        input [15:0] in_val;
        input [2:0] address_val;
        input load_val;
        input [15:0] expected_out;
        begin
            //$display("Set up data while clock is low");
            test_clk = 1'b0;
            test_in = in_val;
            test_address = address_val;
            test_load = load_val;
            #5;
            //$display("%0t | %b | %h | %b | %b | %h", $time, test_clk, test_in, test_address, test_load, test_out);

            //$display("Rising clock edge captures the inputs");
            test_clk = 1'b1;
            #1;
            //$display("%0t | %b | %h | %b | %b | %h", $time, test_clk, test_in, test_address, test_load, test_out);
            if (test_out !== expected_out) begin
                $display("[FAIL @ %0t] after posedge: in=%h address=%b load=%b expected_out=%h got=%h",
                         $time, test_in, test_address, test_load, expected_out, test_out);
                error_occurred = 1;
            end

            //$display("Mutate inputs while clock is high; outputs must hold (address held steady)");
            #4;
            //$display("%0t | %b | %h | %b | %b | %h", $time, test_clk, test_in, test_address, test_load, test_out);
            test_in = ~in_val;
            test_load = ~load_val;
            #2;
            //$display("%0t | %b | %h | %b | %b | %h", $time, test_clk, test_in, test_address, test_load, test_out);
            if (test_out !== expected_out) begin
                $display("[FAIL @ %0t] during clk=1 hold: in=%h address=%b load=%b expected_out=%h got=%h",
                         $time, test_in, test_address, test_load, expected_out, test_out);
                error_occurred = 1;
            end

            //$display("Return clock low");
            test_clk = 1'b0;
            #3;
            $display("%0t | %b | %h | %b | %b | %h", $time, test_clk, test_in, test_address, test_load, test_out);
        end
    endtask

    // actual code running the tasks to do the test cases
    initial begin
        $timeformat(-9, 0, " ns", 8);
        // Print the header for the results table
        $display("Time | clk | in | address | load | out");
        $display("--------------------------------------");
        test_clk = 1'b0;
        test_in = 16'd0;
        test_address = 3'd0;
        test_load = 1'd0;
        #5;
        $display("%0t | %b | %h | %b | %b | %h", $time, test_clk, test_in, test_address, test_load, test_out);

        // Fill in one call per clock cycle: tick_and_check(in, address, load, expected_out)
        // Outputs are X until the first edge, and state carries over between calls.
        // Fill in one call per clock cycle: tick_and_check(in, address, load, expected_out)
        // Outputs are X until the first edge, and state carries over between calls.

        // Phase 1: write a distinct value to every address (out shows the new value after the edge)
        tick_and_check(16'h1234, 3'd0, 1'b1, 16'h1234); // Cycle 1
        tick_and_check(16'h5678, 3'd1, 1'b1, 16'h5678); // Cycle 2
        tick_and_check(16'h9abc, 3'd2, 1'b1, 16'h9abc); // Cycle 3
        tick_and_check(16'hdef0, 3'd3, 1'b1, 16'hdef0); // Cycle 4
        tick_and_check(16'h0f0f, 3'd4, 1'b1, 16'h0f0f); // Cycle 5
        tick_and_check(16'hf0f0, 3'd5, 1'b1, 16'hf0f0); // Cycle 6
        tick_and_check(16'haaaa, 3'd6, 1'b1, 16'haaaa); // Cycle 7
        tick_and_check(16'h5555, 3'd7, 1'b1, 16'h5555); // Cycle 8

        // Phase 2: read everything back in reverse order with load=0 and a junk `in`.
        // Catches mis-decoded writes (crosstalk) and a mux wired to the wrong register.
        tick_and_check(16'hffff, 3'd7, 1'b0, 16'h5555); // Cycle 9
        tick_and_check(16'hffff, 3'd6, 1'b0, 16'haaaa); // Cycle 10
        tick_and_check(16'hffff, 3'd5, 1'b0, 16'hf0f0); // Cycle 11
        tick_and_check(16'hffff, 3'd4, 1'b0, 16'h0f0f); // Cycle 12
        tick_and_check(16'hffff, 3'd3, 1'b0, 16'hdef0); // Cycle 13
        tick_and_check(16'hffff, 3'd2, 1'b0, 16'h9abc); // Cycle 14
        tick_and_check(16'hffff, 3'd1, 1'b0, 16'h5678); // Cycle 15
        tick_and_check(16'hffff, 3'd0, 1'b0, 16'h1234); // Cycle 16

        // Phase 3: overwrite one word, confirm its neighbors are untouched
        tick_and_check(16'hffff, 3'd3, 1'b1, 16'hffff); // Cycle 17: all ones into addr 3
        tick_and_check(16'h0000, 3'd2, 1'b0, 16'h9abc); // Cycle 18: neighbor below unchanged
        tick_and_check(16'h0000, 3'd4, 1'b0, 16'h0f0f); // Cycle 19: neighbor above unchanged
        tick_and_check(16'h0000, 3'd3, 1'b0, 16'hffff); // Cycle 20: addr 3 holds with load=0
        tick_and_check(16'h0000, 3'd3, 1'b1, 16'h0000); // Cycle 21: all zeros into addr 3
        tick_and_check(16'hffff, 3'd3, 1'b0, 16'h0000); // Cycle 22: load=0 must not write

        // Phase 4: boundary addresses and back-to-back writes
        tick_and_check(16'hbeef, 3'd0, 1'b1, 16'hbeef); // Cycle 23: lowest address
        tick_and_check(16'hcafe, 3'd7, 1'b1, 16'hcafe); // Cycle 24: highest address
        tick_and_check(16'h0000, 3'd1, 1'b0, 16'h5678); // Cycle 25: addr 1 still intact
        tick_and_check(16'h0000, 3'd6, 1'b0, 16'haaaa); // Cycle 26: addr 6 still intact
        tick_and_check(16'h0001, 3'd5, 1'b1, 16'h0001); // Cycle 27: write addr 5 (bit 0)
        tick_and_check(16'h8000, 3'd5, 1'b1, 16'h8000); // Cycle 28: overwrite same addr (bit 15)

        // Phase 5: final sweep of what the later writes could have disturbed
        tick_and_check(16'h1234, 3'd0, 1'b0, 16'hbeef); // Cycle 29
        tick_and_check(16'h1234, 3'd7, 1'b0, 16'hcafe); // Cycle 30
        tick_and_check(16'h1234, 3'd5, 1'b0, 16'h8000); // Cycle 31
        tick_and_check(16'h1234, 3'd4, 1'b0, 16'h0f0f); // Cycle 32

        if (error_occurred) begin
            $display("--> RAM8 TEST: FAILED");
            $finish(1);
        end else begin
            $display("--> RAM8 TEST: PASSED");
            $finish(0);
        end
    end
endmodule
