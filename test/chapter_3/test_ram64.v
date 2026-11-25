`timescale 1ns / 1ps

module test_ram64;
    // test signals
    reg test_clk;
    reg [15:0] test_in;
    reg [5:0] test_address;
    reg test_load;
    wire [15:0] test_out;
    reg error_occurred = 0;

    // instantiate the device under test and wire it to the bench signals
    ram64 dut (
        .clk(test_clk),
        .in(test_in),
        .address(test_address),
        .load(test_load),
        .out(test_out)
    );

    // one full clock cycle: set up inputs, rising edge, check, perturb, check, fall
    task tick_and_check;
        input [15:0] in_val;
        input [5:0] address_val;
        input load_val;
        input [15:0] expected_out;
        begin
            // Set up data while clock is low
            test_clk = 1'b0;
            test_in = in_val;
            test_address = address_val;
            test_load = load_val;
            #5;
            //$display("%0t | %b | %h | %h | %b | %h", $time, test_clk, test_in, test_address, test_load, test_out);

            // Rising clock edge captures the inputs
            test_clk = 1'b1;
            #1;
            //$display("%0t | %b | %h | %h | %b | %h", $time, test_clk, test_in, test_address, test_load, test_out);
            if (test_out !== expected_out) begin
                $display("[FAIL @ %0t] after posedge: in=%h address=%h load=%b expected_out=%h got=%h",
                         $time, test_in, test_address, test_load, expected_out, test_out);
                error_occurred = 1;
            end

            // Mutate inputs while clock is high; outputs must hold (address held steady)
            #4;
            //$display("%0t | %b | %h | %h | %b | %h", $time, test_clk, test_in, test_address, test_load, test_out);
            test_in = ~in_val;
            test_load = ~load_val;
            #2;
            //$display("%0t | %b | %h | %h | %b | %h", $time, test_clk, test_in, test_address, test_load, test_out);
            if (test_out !== expected_out) begin
                $display("[FAIL @ %0t] during clk=1 hold: in=%h address=%h load=%b expected_out=%h got=%h",
                         $time, test_in, test_address, test_load, expected_out, test_out);
                error_occurred = 1;
            end

            // Return clock low
            test_clk = 1'b0;
            #3;
            $display("%0t | %b | %h | %h | %b | %h", $time, test_clk, test_in, test_address, test_load, test_out);
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
        test_address = 6'd0;
        test_load = 1'd0;
        #5;
        $display("%0t | %b | %h | %h | %b | %h", $time, test_clk, test_in, test_address, test_load, test_out);

        // Fill in one call per clock cycle: tick_and_check(in, address, load, expected_out)
        // Outputs are X until the first edge, and state carries over between calls.
                // Fill in one call per clock cycle: tick_and_check(in, address, load, expected_out)
        // Outputs are X until the first edge, and state carries over between calls.
        // Address format: 6'b<bank 5:3>_<word 2:0>

        // Phase 1: same word (011) in every bank. Exercises the upper-bit decode.
        tick_and_check(16'h0a01, 6'b000_011, 1'b1, 16'h0a01); // Cycle 1
        tick_and_check(16'h1b02, 6'b001_011, 1'b1, 16'h1b02); // Cycle 2
        tick_and_check(16'h2c04, 6'b010_011, 1'b1, 16'h2c04); // Cycle 3
        tick_and_check(16'h3d08, 6'b011_011, 1'b1, 16'h3d08); // Cycle 4
        tick_and_check(16'h4e10, 6'b100_011, 1'b1, 16'h4e10); // Cycle 5
        tick_and_check(16'h5f20, 6'b101_011, 1'b1, 16'h5f20); // Cycle 6
        tick_and_check(16'h6a40, 6'b110_011, 1'b1, 16'h6a40); // Cycle 7
        tick_and_check(16'h7b80, 6'b111_011, 1'b1, 16'h7b80); // Cycle 8

        // Phase 2: every other word in bank 101 (011 is skipped so Phase 1's value must survive).
        // Exercises the lower-bit decode inside one RAM8.
        tick_and_check(16'h8001, 6'b101_000, 1'b1, 16'h8001); // Cycle 9
        tick_and_check(16'h9002, 6'b101_001, 1'b1, 16'h9002); // Cycle 10
        tick_and_check(16'ha003, 6'b101_010, 1'b1, 16'ha003); // Cycle 11
        tick_and_check(16'hb005, 6'b101_100, 1'b1, 16'hb005); // Cycle 12
        tick_and_check(16'hc006, 6'b101_101, 1'b1, 16'hc006); // Cycle 13
        tick_and_check(16'hd007, 6'b101_110, 1'b1, 16'hd007); // Cycle 14
        tick_and_check(16'he008, 6'b101_111, 1'b1, 16'he008); // Cycle 15

        // Phase 3: read bank 101 back in reverse, load=0 with junk on `in`
        tick_and_check(16'hffff, 6'b101_111, 1'b0, 16'he008); // Cycle 16
        tick_and_check(16'hffff, 6'b101_110, 1'b0, 16'hd007); // Cycle 17
        tick_and_check(16'hffff, 6'b101_101, 1'b0, 16'hc006); // Cycle 18
        tick_and_check(16'hffff, 6'b101_100, 1'b0, 16'hb005); // Cycle 19
        tick_and_check(16'hffff, 6'b101_011, 1'b0, 16'h5f20); // Cycle 20: Phase 1 value intact
        tick_and_check(16'hffff, 6'b101_010, 1'b0, 16'ha003); // Cycle 21
        tick_and_check(16'hffff, 6'b101_001, 1'b0, 16'h9002); // Cycle 22
        tick_and_check(16'hffff, 6'b101_000, 1'b0, 16'h8001); // Cycle 23

        // Phase 4: read the Phase 1 words back across banks (bank 101 was already checked)
        tick_and_check(16'hffff, 6'b111_011, 1'b0, 16'h7b80); // Cycle 24
        tick_and_check(16'hffff, 6'b110_011, 1'b0, 16'h6a40); // Cycle 25
        tick_and_check(16'hffff, 6'b100_011, 1'b0, 16'h4e10); // Cycle 26
        tick_and_check(16'hffff, 6'b011_011, 1'b0, 16'h3d08); // Cycle 27
        tick_and_check(16'hffff, 6'b010_011, 1'b0, 16'h2c04); // Cycle 28
        tick_and_check(16'hffff, 6'b001_011, 1'b0, 16'h1b02); // Cycle 29
        tick_and_check(16'hffff, 6'b000_011, 1'b0, 16'h0a01); // Cycle 30

        // Phase 5: overwrite one word, check the neighbors in adjacent banks, then zero it
        tick_and_check(16'hffff, 6'b011_011, 1'b1, 16'hffff); // Cycle 31
        tick_and_check(16'h0000, 6'b010_011, 1'b0, 16'h2c04); // Cycle 32: bank below unchanged
        tick_and_check(16'h0000, 6'b100_011, 1'b0, 16'h4e10); // Cycle 33: bank above unchanged
        tick_and_check(16'h0000, 6'b011_011, 1'b0, 16'hffff); // Cycle 34: holds with load=0
        tick_and_check(16'h0000, 6'b011_011, 1'b1, 16'h0000); // Cycle 35: all zeros
        tick_and_check(16'hffff, 6'b011_011, 1'b0, 16'h0000); // Cycle 36: load=0 must not write

        // Phase 6: boundary addresses, then a final sweep
        tick_and_check(16'hbeef, 6'b000_000, 1'b1, 16'hbeef); // Cycle 37: lowest address
        tick_and_check(16'hcafe, 6'b111_111, 1'b1, 16'hcafe); // Cycle 38: highest address
        tick_and_check(16'h1234, 6'b000_000, 1'b0, 16'hbeef); // Cycle 39
        tick_and_check(16'h1234, 6'b111_111, 1'b0, 16'hcafe); // Cycle 40
        tick_and_check(16'h1234, 6'b101_000, 1'b0, 16'h8001); // Cycle 41
        tick_and_check(16'h1234, 6'b000_011, 1'b0, 16'h0a01); // Cycle 42
        tick_and_check(16'h1234, 6'b111_011, 1'b0, 16'h7b80); // Cycle 43

        // Phase 7: back-to-back overwrite (bit 0, then bit 15), neighbors in the same RAM8 untouched
        tick_and_check(16'h0001, 6'b101_101, 1'b1, 16'h0001); // Cycle 44
        tick_and_check(16'h8000, 6'b101_101, 1'b1, 16'h8000); // Cycle 45
        tick_and_check(16'h0000, 6'b101_100, 1'b0, 16'hb005); // Cycle 46
        tick_and_check(16'h0000, 6'b101_110, 1'b0, 16'hd007); // Cycle 47
        tick_and_check(16'h0000, 6'b101_101, 1'b0, 16'h8000); // Cycle 48

        if (error_occurred) begin
            $display("--> RAM64 TEST: FAILED");
            $finish(1);
        end else begin
            $display("--> RAM64 TEST: PASSED");
            $finish(0);
        end
    end
endmodule
