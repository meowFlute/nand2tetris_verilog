`timescale 1ns/1ps
// Runs Fill.hack on the full computer and checks the screen memory map:
//   pass 1: key = 0       -> screen should be all white (0x0000)
//   pass 2: key != 0      -> screen should be all black (0xFFFF)
//   pass 3: key = 0 again -> screen should go back to white
//
// Fill.asm loops forever, so we sync to the program instead of counting cycles:
// the key is changed while pc == 0 (top of LOOP, just before it reads KBD), then
// we run until pc returns to 0, i.e. exactly one full pass over the screen.
module test_computer_Fill;
    localparam MAX_CYCLES = 400000;   // timeout per pass (a pass is ~123k cycles)

    reg         clk = 0;
    reg         reset = 1;
    reg  [15:0] key = 16'd0;
    integer     errors;

    computer #(.PROGRAM("src/chapter_4/Fill.hack")) dut (.clk(clk), .reset(reset), .key(key));

    always #5 clk = ~clk;

    // Screen is two ram4k instances: words 0-4095 in ram_lo, 4096-8191 in ram_hi
    function [15:0] screen_word(input integer n);
        screen_word = (n < 4096) ? dut.mem.scr.ram_lo.mem[n]
                                 : dut.mem.scr.ram_hi.mem[n - 4096];
    endfunction

    task fill_screen(input [15:0] value);
        integer n;
        begin
            for (n = 0; n < 4096; n = n + 1) begin
                dut.mem.scr.ram_lo.mem[n] = value;
                dut.mem.scr.ram_hi.mem[n] = value;
            end
        end
    endtask

    // Leave pc == 0, then run until it comes back to 0 (one trip around the program).
    task run_one_pass;
        integer cycles;
        begin
            cycles = 0;
            @(posedge clk); #1; cycles = cycles + 1;
            while (dut.pc !== 15'd0 && cycles < MAX_CYCLES) begin
                @(posedge clk); #1; cycles = cycles + 1;
            end
            if (dut.pc !== 15'd0) begin
                $display("FAIL: timeout, pc never returned to 0 after %0d cycles", cycles);
                errors = errors + 1;
            end else
                $display("      pass took %0d cycles", cycles);
        end
    endtask

    task check_screen(input [15:0] expected, input [255:0] label);
        integer n, bad, first_bad;
        begin
            bad = 0; first_bad = -1;
            for (n = 0; n < 8192; n = n + 1)
                if (screen_word(n) !== expected) begin
                    if (bad == 0) first_bad = n;
                    bad = bad + 1;
                end
            if (bad == 0)
                $display("PASS: %0s (all 8192 words = %h)", label, expected);
            else begin
                $display("FAIL: %0s: %0d words != %h (first at screen word %0d, got %h)",
                         label, bad, expected, first_bad, screen_word(first_bad));
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        errors = 0;

        // start from the opposite of what we expect so a no-op program can't pass
        fill_screen(16'hFFFF);

        // reset for two clock edges; after release pc == 0
        repeat (2) @(posedge clk);
        #1 reset = 0;

        // pass 1: no key pressed -> white
        key = 16'd0;
        run_one_pass;
        check_screen(16'h0000, "no key   -> white");

        // pass 2: key pressed -> black
        key = 16'd75;   // 'K'
        run_one_pass;
        check_screen(16'hFFFF, "key down -> black");

        // pass 3: key released -> white again
        key = 16'd0;
        run_one_pass;
        check_screen(16'h0000, "key up   -> white");

        if (errors == 0) $display("PASS: Fill");
        else             $display("FAIL: Fill (%0d checks failed)", errors);
        $finish;
    end
endmodule
