`timescale 1ns / 1ps

module test_register16;
    // test signals
    reg test_clk;
    reg [15:0] test_in;
    reg test_load;
    wire [15:0] test_out;
    reg error_occurred = 0;

    // instantiate the device under test and wire it to the bench signals
    register16 dut (
        .clk(test_clk),
        .in(test_in),
        .load(test_load),
        .out(test_out)
    );

    // one full clock cycle: set up inputs, rising edge, check, perturb, check, fall
    task tick_and_check;
        input [15:0] in_val;
        input load_val;
        input [15:0] expected_out;
        begin
            // Set up data while clock is low
            test_clk = 1'b0;
            test_in = in_val;
            test_load = load_val;
            #5;
            //$display("%0t | %b | %h | %b | %h", $time, test_clk, test_in, test_load, test_out);

            // Rising clock edge captures the inputs
            test_clk = 1'b1;
            #1;
            //$display("%0t | %b | %h | %b | %h", $time, test_clk, test_in, test_load, test_out);
            if (test_out !== expected_out) begin
                $display("[FAIL @ %0t] after posedge: in=%h load=%b expected_out=%h got=%h",
                         $time, test_in, test_load, expected_out, test_out);
                error_occurred = 1;
            end

            // Mutate inputs while clock is high; outputs must hold
            #4;
            //$display("%0t | %b | %h | %b | %h", $time, test_clk, test_in, test_load, test_out);
            test_in = ~in_val;
            test_load = ~load_val;
            #2;
            //$display("%0t | %b | %h | %b | %h", $time, test_clk, test_in, test_load, test_out);
            if (test_out !== expected_out) begin
                $display("[FAIL @ %0t] during clk=1 hold: in=%h load=%b expected_out=%h got=%h",
                         $time, test_in, test_load, expected_out, test_out);
                error_occurred = 1;
            end

            // Return clock low
            test_clk = 1'b0;
            #3;
            $display("%0t | %b | %h | %b | %h", $time, test_clk, test_in, test_load, test_out);
        end
    endtask

    // actual code running the tasks to do the test cases
    initial begin
        $timeformat(-9, 0, " ns", 8);
        // Print the header for the results table
        $display("Time | clk | in | load | out");
        $display("----------------------------");
        test_clk = 1'b0;
        test_in = 16'd0;
        test_load = 1'd0;
        #5;
        $display("%0t | %b | %h | %b | %h", $time, test_clk, test_in, test_load, test_out);

        // Fill in one call per clock cycle: tick_and_check(in, load, expected_out)
        // Outputs are X until the first edge, and state carries over between calls.
        // init to a known value
        tick_and_check(16'h0000, 1'b1, 16'h0000); // 1:  init, load 0

        // hold ignores in (every bit differs from state)
        tick_and_check(16'hFFFF, 1'b0, 16'h0000); // 2:  hold 0, in=FFFF
        
        // load all ones, then hold against the opposite value
        tick_and_check(16'hFFFF, 1'b1, 16'hFFFF); // 3:  load FFFF
        tick_and_check(16'h0000, 1'b0, 16'hFFFF); // 4:  hold FFFF, in=0000
        tick_and_check(16'hFFFF, 1'b1, 16'hFFFF); // 5:  load same value
        
        // alternating patterns
        tick_and_check(16'h5555, 1'b1, 16'h5555); // 6:  load 5555
        tick_and_check(16'hAAAA, 1'b0, 16'h5555); // 7:  hold 5555, in=AAAA
        tick_and_check(16'hAAAA, 1'b1, 16'hAAAA); // 8:  load AAAA
        tick_and_check(16'h5555, 1'b0, 16'hAAAA); // 9:  hold AAAA, in=5555
        
        // walking one, loading each in turn
        tick_and_check(16'h0001, 1'b1, 16'h0001); // 10
        tick_and_check(16'h0002, 1'b1, 16'h0002); // 11
        tick_and_check(16'h0004, 1'b1, 16'h0004); // 12
        tick_and_check(16'h0008, 1'b1, 16'h0008); // 13
        tick_and_check(16'h0010, 1'b1, 16'h0010); // 14
        tick_and_check(16'h0020, 1'b1, 16'h0020); // 15
        tick_and_check(16'h0040, 1'b1, 16'h0040); // 16
        tick_and_check(16'h0080, 1'b1, 16'h0080); // 17
        tick_and_check(16'h0100, 1'b1, 16'h0100); // 18
        tick_and_check(16'h0200, 1'b1, 16'h0200); // 19
        tick_and_check(16'h0400, 1'b1, 16'h0400); // 20
        tick_and_check(16'h0800, 1'b1, 16'h0800); // 21
        tick_and_check(16'h1000, 1'b1, 16'h1000); // 22
        tick_and_check(16'h2000, 1'b1, 16'h2000); // 23
        tick_and_check(16'h4000, 1'b1, 16'h4000); // 24
        tick_and_check(16'h8000, 1'b1, 16'h8000); // 25
        
        // hold the last walking-one value while in changes
        tick_and_check(16'h7FFF, 1'b0, 16'h8000); // 26: hold, in=7FFF
        
        // non-pattern value, as a general sanity check
        tick_and_check(16'h1234, 1'b1, 16'h1234); // 27: load arbitrary value
        tick_and_check(16'hEDCB, 1'b0, 16'h1234); // 28: hold, in=~1234

        if (error_occurred) begin
            $display("--> REGISTER16 TEST: FAILED");
            $finish(1);
        end else begin
            $display("--> REGISTER16 TEST: PASSED");
            $finish(0);
        end
    end
endmodule
