module half_adder (
    input wire a,
    input wire b,
    output wire sum,
    output wire carry
);

    and_gate derived_and (.a(a), .b(b), .out(carry));
    xor_gate derived_xor (.a(a), .b(b), .out(sum));

endmodule
