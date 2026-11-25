module or_gate (
    input wire a,
    input wire b,
    output wire out
);

    // OR is equivalent to NOT(A) AND NOT(B)
    wire nota;
    wire notb;

    not_gate not_a (.in(a), .out(nota));
    not_gate not_b (.in(b), .out(notb));
    
    nand_gate nand_nota_notb (
        .a(nota),
        .b(notb),
        .out(out)
    );

endmodule
