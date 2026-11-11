module xor_gate (
    input wire a,
    input wire b,
    output wire out
);
    /* This method ends up being 9 NAND gates, where 4 do nothing. 5 would be
     * easy to do.
     * 
     * I figured that out by using my yosys visualization in the makefile!
     *
     * // I don't remember how I came up with this but kind of cool
     * wire nota;
     * wire notb;
     * wire or1;
     * wire or2;

     * not_gate not_a (.in(a), .out(nota));
     * not_gate not_b (.in(b), .out(notb));

     * and_gate and_anotb (.a(a), .b(notb), .out(or1));
     * and_gate and_bnota (.a(b), .b(nota), .out(or2));

     * or_gate or_out (.a(or1), .b(or2), .out(out));
     */
    
    // the optimized method removes two sequential nots in each branch by using 
    // NAND instead of AND, and minimizing the final OR (which was NOT AND)
    not_gate not_a (.in(a), .out(nota));
    not_gate not_b (.in(b), .out(notb));

    // NOT of the OR built in here
    nand_gate nand_anotb (.a(a), .b(notb), .out(or1));
    nand_gate nand_bnota (.a(b), .b(nota), .out(or2));

    // OR from above finished with a final NAND
    nand_gate nand_finish_or (.a(or1), .b(or2), .out(out));

endmodule
