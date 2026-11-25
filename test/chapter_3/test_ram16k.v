`timescale 1ns / 1ps

module test_ram16k;
    // test signals
    reg test_clk;
    reg [15:0] test_in;
    reg [13:0] test_address;
    reg test_load;
    wire [15:0] test_out;
    reg error_occurred = 0;

    // instantiate the device under test and wire it to the bench signals
    ram16k dut (
        .clk(test_clk),
        .in(test_in),
        .address(test_address),
        .load(test_load),
        .out(test_out)
    );

    // one full clock cycle: set up inputs, rising edge, check, perturb, check, fall
    task tick_and_check;
        input [15:0] in_val;
        input [13:0] address_val;
        input load_val;
        input [15:0] expected_out;
        begin
            // Set up data while clock is low
            test_clk = 1'b0;
            test_in = in_val;
            test_address = address_val;
            test_load = load_val;
            #5;
            $display("%0t | %b | %h | %h | %b | %h", $time, test_clk, test_in, test_address, test_load, test_out);

            // Rising clock edge captures the inputs
            test_clk = 1'b1;
            #1;
            $display("%0t | %b | %h | %h | %b | %h", $time, test_clk, test_in, test_address, test_load, test_out);
            if (test_out !== expected_out) begin
                $display("[FAIL @ %0t] after posedge: in=%h address=%h load=%b expected_out=%h got=%h",
                         $time, test_in, test_address, test_load, expected_out, test_out);
                error_occurred = 1;
            end

            // Mutate inputs while clock is high; outputs must hold (address held steady)
            #4;
            $display("%0t | %b | %h | %h | %b | %h", $time, test_clk, test_in, test_address, test_load, test_out);
            test_in = ~in_val;
            test_load = ~load_val;
            #2;
            $display("%0t | %b | %h | %h | %b | %h", $time, test_clk, test_in, test_address, test_load, test_out);
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
        test_address = 14'd0;
        test_load = 1'd0;
        #5;
        $display("%0t | %b | %h | %h | %b | %h", $time, test_clk, test_in, test_address, test_load, test_out);

        // Fill in one call per clock cycle: tick_and_check(in, address, load, expected_out)
        // Outputs are X until the first edge, and state carries over between calls.
                // Fill in one call per clock cycle: tick_and_check(in, address, load, expected_out)
        // Outputs are X until the first edge, and state carries over between calls.

        // Phase 1: write address 0, each single-bit address (walking one), then all ones
        tick_and_check(16'h1357, 14'b00_0000_0000_0000, 1'b1, 16'h1357); // Cycle 1
        tick_and_check(16'h2468, 14'b00_0000_0000_0001, 1'b1, 16'h2468); // Cycle 2
        tick_and_check(16'h3579, 14'b00_0000_0000_0010, 1'b1, 16'h3579); // Cycle 3
        tick_and_check(16'h468a, 14'b00_0000_0000_0100, 1'b1, 16'h468a); // Cycle 4
        tick_and_check(16'h579b, 14'b00_0000_0000_1000, 1'b1, 16'h579b); // Cycle 5
        tick_and_check(16'h68ac, 14'b00_0000_0001_0000, 1'b1, 16'h68ac); // Cycle 6
        tick_and_check(16'h79bd, 14'b00_0000_0010_0000, 1'b1, 16'h79bd); // Cycle 7
        tick_and_check(16'h8ace, 14'b00_0000_0100_0000, 1'b1, 16'h8ace); // Cycle 8
        tick_and_check(16'h9bdf, 14'b00_0000_1000_0000, 1'b1, 16'h9bdf); // Cycle 9
        tick_and_check(16'hac01, 14'b00_0001_0000_0000, 1'b1, 16'hac01); // Cycle 10
        tick_and_check(16'hbd12, 14'b00_0010_0000_0000, 1'b1, 16'hbd12); // Cycle 11
        tick_and_check(16'hce23, 14'b00_0100_0000_0000, 1'b1, 16'hce23); // Cycle 12
        tick_and_check(16'hdf34, 14'b00_1000_0000_0000, 1'b1, 16'hdf34); // Cycle 13
        tick_and_check(16'he045, 14'b01_0000_0000_0000, 1'b1, 16'he045); // Cycle 14
        tick_and_check(16'hf156, 14'b10_0000_0000_0000, 1'b1, 16'hf156); // Cycle 15
        tick_and_check(16'h0a67, 14'b11_1111_1111_1111, 1'b1, 16'h0a67); // Cycle 16

        // Phase 2: read everything back in reverse, load=0, junk on `in`
        tick_and_check(16'hffff, 14'b11_1111_1111_1111, 1'b0, 16'h0a67); // Cycle 17
        tick_and_check(16'hffff, 14'b10_0000_0000_0000, 1'b0, 16'hf156); // Cycle 18
        tick_and_check(16'hffff, 14'b01_0000_0000_0000, 1'b0, 16'he045); // Cycle 19
        tick_and_check(16'hffff, 14'b00_1000_0000_0000, 1'b0, 16'hdf34); // Cycle 20
        tick_and_check(16'hffff, 14'b00_0100_0000_0000, 1'b0, 16'hce23); // Cycle 21
        tick_and_check(16'hffff, 14'b00_0010_0000_0000, 1'b0, 16'hbd12); // Cycle 22
        tick_and_check(16'hffff, 14'b00_0001_0000_0000, 1'b0, 16'hac01); // Cycle 23
        tick_and_check(16'hffff, 14'b00_0000_1000_0000, 1'b0, 16'h9bdf); // Cycle 24
        tick_and_check(16'hffff, 14'b00_0000_0100_0000, 1'b0, 16'h8ace); // Cycle 25
        tick_and_check(16'hffff, 14'b00_0000_0010_0000, 1'b0, 16'h79bd); // Cycle 26
        tick_and_check(16'hffff, 14'b00_0000_0001_0000, 1'b0, 16'h68ac); // Cycle 27
        tick_and_check(16'hffff, 14'b00_0000_0000_1000, 1'b0, 16'h579b); // Cycle 28
        tick_and_check(16'hffff, 14'b00_0000_0000_0100, 1'b0, 16'h468a); // Cycle 29
        tick_and_check(16'hffff, 14'b00_0000_0000_0010, 1'b0, 16'h3579); // Cycle 30
        tick_and_check(16'hffff, 14'b00_0000_0000_0001, 1'b0, 16'h2468); // Cycle 31
        tick_and_check(16'hffff, 14'b00_0000_0000_0000, 1'b0, 16'h1357); // Cycle 32

        // Phase 3: walking zero on the top bits and one mid bit, then re-check older words
        tick_and_check(16'h0fed, 14'b01_1111_1111_1111, 1'b1, 16'h0fed); // Cycle 33
        tick_and_check(16'h1eda, 14'b10_1111_1111_1111, 1'b1, 16'h1eda); // Cycle 34
        tick_and_check(16'h2dcb, 14'b11_1111_1111_1110, 1'b1, 16'h2dcb); // Cycle 35
        tick_and_check(16'h3cba, 14'b11_0111_1111_1111, 1'b1, 16'h3cba); // Cycle 36
        tick_and_check(16'hffff, 14'b11_1111_1111_1111, 1'b0, 16'h0a67); // Cycle 37: all ones intact
        tick_and_check(16'hffff, 14'b00_0000_0000_0000, 1'b0, 16'h1357); // Cycle 38: address 0 intact
        tick_and_check(16'hffff, 14'b10_0000_0000_0000, 1'b0, 16'hf156); // Cycle 39
        tick_and_check(16'hffff, 14'b01_1111_1111_1111, 1'b0, 16'h0fed); // Cycle 40
        tick_and_check(16'hffff, 14'b10_1111_1111_1111, 1'b0, 16'h1eda); // Cycle 41
        tick_and_check(16'hffff, 14'b11_1111_1111_1110, 1'b0, 16'h2dcb); // Cycle 42
        tick_and_check(16'hffff, 14'b11_0111_1111_1111, 1'b0, 16'h3cba); // Cycle 43

        // Phase 4: stuck bits and load gating on a mid-range address, neighbors untouched
        tick_and_check(16'hffff, 14'b01_0101_0101_0101, 1'b1, 16'hffff); // Cycle 44
        tick_and_check(16'h0000, 14'b01_0101_0101_0101, 1'b1, 16'h0000); // Cycle 45
        tick_and_check(16'hffff, 14'b01_0101_0101_0101, 1'b0, 16'h0000); // Cycle 46: load=0 must not write
        tick_and_check(16'h0001, 14'b01_0101_0101_0101, 1'b1, 16'h0001); // Cycle 47: bit 0
        tick_and_check(16'h8000, 14'b01_0101_0101_0101, 1'b1, 16'h8000); // Cycle 48: bit 15
        tick_and_check(16'h0000, 14'b00_0000_0000_0001, 1'b0, 16'h2468); // Cycle 49: neighbor intact
        tick_and_check(16'h0000, 14'b00_0000_0000_0000, 1'b0, 16'h1357); // Cycle 50
        tick_and_check(16'h0000, 14'b01_0101_0101_0101, 1'b0, 16'h8000); // Cycle 51

        if (error_occurred) begin
            $display("--> RAM16K TEST: FAILED");
            $finish(1);
        end else begin
            $display("--> RAM16K TEST: PASSED");
            $finish(0);
        end
    end
endmodule
