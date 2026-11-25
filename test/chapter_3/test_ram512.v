`timescale 1ns / 1ps

module test_ram512;
    // test signals
    reg test_clk;
    reg [15:0] test_in;
    reg [8:0] test_address;
    reg test_load;
    wire [15:0] test_out;
    reg error_occurred = 0;

    // instantiate the device under test and wire it to the bench signals
    ram512 dut (
        .clk(test_clk),
        .in(test_in),
        .address(test_address),
        .load(test_load),
        .out(test_out)
    );

    // one full clock cycle: set up inputs, rising edge, check, perturb, check, fall
    task tick_and_check;
        input [15:0] in_val;
        input [8:0] address_val;
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
        test_address = 9'd0;
        test_load = 1'd0;
        #5;
        $display("%0t | %b | %h | %h | %b | %h", $time, test_clk, test_in, test_address, test_load, test_out);

        // Fill in one call per clock cycle: tick_and_check(in, address, load, expected_out)
        // Outputs are X until the first edge, and state carries over between calls.
        // Address format: 9'b<bank 8:6>_<ram8 5:3>_<word 2:0>

        // Phase 1: vary only the bank (mid=010, word=011). Exercises the top-level decode.
        tick_and_check(16'h0a01, 9'b000_010_011, 1'b1, 16'h0a01); // Cycle 1
        tick_and_check(16'h1b02, 9'b001_010_011, 1'b1, 16'h1b02); // Cycle 2
        tick_and_check(16'h2c04, 9'b010_010_011, 1'b1, 16'h2c04); // Cycle 3
        tick_and_check(16'h3d08, 9'b011_010_011, 1'b1, 16'h3d08); // Cycle 4
        tick_and_check(16'h4e10, 9'b100_010_011, 1'b1, 16'h4e10); // Cycle 5
        tick_and_check(16'h5f20, 9'b101_010_011, 1'b1, 16'h5f20); // Cycle 6
        tick_and_check(16'h6a40, 9'b110_010_011, 1'b1, 16'h6a40); // Cycle 7
        tick_and_check(16'h7b80, 9'b111_010_011, 1'b1, 16'h7b80); // Cycle 8

        // Phase 2: vary only the middle field in bank 101 (word=011; mid 010 skipped, Phase 1 owns it)
        tick_and_check(16'h8001, 9'b101_000_011, 1'b1, 16'h8001); // Cycle 9
        tick_and_check(16'h9002, 9'b101_001_011, 1'b1, 16'h9002); // Cycle 10
        tick_and_check(16'ha003, 9'b101_011_011, 1'b1, 16'ha003); // Cycle 11
        tick_and_check(16'hb005, 9'b101_100_011, 1'b1, 16'hb005); // Cycle 12
        tick_and_check(16'hc006, 9'b101_101_011, 1'b1, 16'hc006); // Cycle 13
        tick_and_check(16'hd007, 9'b101_110_011, 1'b1, 16'hd007); // Cycle 14
        tick_and_check(16'he008, 9'b101_111_011, 1'b1, 16'he008); // Cycle 15

        // Phase 3: vary only the word in bank 101, mid 010 (word 011 skipped, Phase 1 owns it)
        tick_and_check(16'h1001, 9'b101_010_000, 1'b1, 16'h1001); // Cycle 16
        tick_and_check(16'h2002, 9'b101_010_001, 1'b1, 16'h2002); // Cycle 17
        tick_and_check(16'h3003, 9'b101_010_010, 1'b1, 16'h3003); // Cycle 18
        tick_and_check(16'h4005, 9'b101_010_100, 1'b1, 16'h4005); // Cycle 19
        tick_and_check(16'h5006, 9'b101_010_101, 1'b1, 16'h5006); // Cycle 20
        tick_and_check(16'h6007, 9'b101_010_110, 1'b1, 16'h6007); // Cycle 21
        tick_and_check(16'h7008, 9'b101_010_111, 1'b1, 16'h7008); // Cycle 22

        // Phase 4: read everything back in reverse, load=0, junk on `in`
        // 4a: Phase 2 words
        tick_and_check(16'hffff, 9'b101_111_011, 1'b0, 16'he008); // Cycle 23
        tick_and_check(16'hffff, 9'b101_110_011, 1'b0, 16'hd007); // Cycle 24
        tick_and_check(16'hffff, 9'b101_101_011, 1'b0, 16'hc006); // Cycle 25
        tick_and_check(16'hffff, 9'b101_100_011, 1'b0, 16'hb005); // Cycle 26
        tick_and_check(16'hffff, 9'b101_011_011, 1'b0, 16'ha003); // Cycle 27
        tick_and_check(16'hffff, 9'b101_001_011, 1'b0, 16'h9002); // Cycle 28
        tick_and_check(16'hffff, 9'b101_000_011, 1'b0, 16'h8001); // Cycle 29
        // 4b: Phase 3 words
        tick_and_check(16'hffff, 9'b101_010_111, 1'b0, 16'h7008); // Cycle 30
        tick_and_check(16'hffff, 9'b101_010_110, 1'b0, 16'h6007); // Cycle 31
        tick_and_check(16'hffff, 9'b101_010_101, 1'b0, 16'h5006); // Cycle 32
        tick_and_check(16'hffff, 9'b101_010_100, 1'b0, 16'h4005); // Cycle 33
        tick_and_check(16'hffff, 9'b101_010_010, 1'b0, 16'h3003); // Cycle 34
        tick_and_check(16'hffff, 9'b101_010_001, 1'b0, 16'h2002); // Cycle 35
        tick_and_check(16'hffff, 9'b101_010_000, 1'b0, 16'h1001); // Cycle 36
        // 4c: the word Phase 2 and Phase 3 both bracket, then the other banks from Phase 1
        tick_and_check(16'hffff, 9'b101_010_011, 1'b0, 16'h5f20); // Cycle 37: Phase 1 value intact
        tick_and_check(16'hffff, 9'b111_010_011, 1'b0, 16'h7b80); // Cycle 38
        tick_and_check(16'hffff, 9'b110_010_011, 1'b0, 16'h6a40); // Cycle 39
        tick_and_check(16'hffff, 9'b100_010_011, 1'b0, 16'h4e10); // Cycle 40
        tick_and_check(16'hffff, 9'b011_010_011, 1'b0, 16'h3d08); // Cycle 41
        tick_and_check(16'hffff, 9'b010_010_011, 1'b0, 16'h2c04); // Cycle 42
        tick_and_check(16'hffff, 9'b001_010_011, 1'b0, 16'h1b02); // Cycle 43
        tick_and_check(16'hffff, 9'b000_010_011, 1'b0, 16'h0a01); // Cycle 44

        // Phase 5: overwrite one word, check adjacent banks, then zero it
        tick_and_check(16'hffff, 9'b011_010_011, 1'b1, 16'hffff); // Cycle 45
        tick_and_check(16'h0000, 9'b010_010_011, 1'b0, 16'h2c04); // Cycle 46: bank below unchanged
        tick_and_check(16'h0000, 9'b100_010_011, 1'b0, 16'h4e10); // Cycle 47: bank above unchanged
        tick_and_check(16'h0000, 9'b011_010_011, 1'b0, 16'hffff); // Cycle 48: holds with load=0
        tick_and_check(16'h0000, 9'b011_010_011, 1'b1, 16'h0000); // Cycle 49: all zeros
        tick_and_check(16'hffff, 9'b011_010_011, 1'b0, 16'h0000); // Cycle 50: load=0 must not write

        // Phase 6: corner addresses, then spot-check older data
        tick_and_check(16'hbeef, 9'b000_000_000, 1'b1, 16'hbeef); // Cycle 51: lowest address
        tick_and_check(16'hcafe, 9'b111_111_111, 1'b1, 16'hcafe); // Cycle 52: highest address
        tick_and_check(16'h1234, 9'b000_000_000, 1'b0, 16'hbeef); // Cycle 53
        tick_and_check(16'h1234, 9'b111_111_111, 1'b0, 16'hcafe); // Cycle 54
        tick_and_check(16'h1234, 9'b101_000_011, 1'b0, 16'h8001); // Cycle 55
        tick_and_check(16'h1234, 9'b000_010_011, 1'b0, 16'h0a01); // Cycle 56
        tick_and_check(16'h1234, 9'b111_010_011, 1'b0, 16'h7b80); // Cycle 57

        // Phase 7: back-to-back rewrite (bit 0, then bit 15), same-bank neighbors untouched
        tick_and_check(16'h0001, 9'b101_101_011, 1'b1, 16'h0001); // Cycle 58
        tick_and_check(16'h8000, 9'b101_101_011, 1'b1, 16'h8000); // Cycle 59
        tick_and_check(16'h0000, 9'b101_100_011, 1'b0, 16'hb005); // Cycle 60
        tick_and_check(16'h0000, 9'b101_110_011, 1'b0, 16'hd007); // Cycle 61
        tick_and_check(16'h0000, 9'b101_101_011, 1'b0, 16'h8000); // Cycle 62

        if (error_occurred) begin
            $display("--> RAM512 TEST: FAILED");
            $finish(1);
        end else begin
            $display("--> RAM512 TEST: PASSED");
            $finish(0);
        end
    end
endmodule
