module mux (
    input wire a,
    input wire b,
    input wire sel,
    output wire out
);
    
    wire notsel;
    wire w1;
    wire w2;

    /* original method
        * This is really intuitive and just works, but when you look at the
        * nand graph again the ANDs followed by an OR generate useless NOTs in
        * the middle
        *
        * we can improve over the below 
        *
    not_gate not1 (.in(sel), .out(notsel));

    and_gate a_selector (.a(a), .b(notsel), .out(w1));
    and_gate b_selector (.a(b), .b(sel), .out(w2));

    or_gate or_selectors (.a(w1), .b(w2), .out(out));
        * 
        * and in order to improve we'll do the following:
        */

    not_gate not1 (.in(sel), .out(notsel));

    nand_gate a_selector (.a(a), .b(notsel), .out(w1));
    nand_gate b_selector (.a(b), .b(sel), .out(w2));

    nand_gate or_selectors (.a(w1), .b(w2), .out(out));

endmodule
