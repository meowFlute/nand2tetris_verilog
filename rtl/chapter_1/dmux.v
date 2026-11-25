module dmux (
    input wire in,
    input wire sel,
    output wire a,
    output wire b
);

    wire notsel;

    not_gate not_select (.in(sel), .out(notsel));

    and_gate a_select(.a(in), .b(notsel), .out(a));
    and_gate b_select(.a(in), .b(sel), .out(b));

endmodule
