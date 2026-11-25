module full_adder (
    input wire a,
    input wire b,
    input wire c,
    output wire sum,
    output wire carry
);

    wire ab_sum;
    wire ab_carry;
    wire c_carry;

    half_adder first_half (.a(a), .b(b), .sum(ab_sum), .carry(ab_carry));
    half_adder second_half (.a(ab_sum), .b(c), .sum(sum), .carry(c_carry));
    or_gate combined_carry (.a(ab_carry), .b(c_carry), .out(carry));

endmodule
