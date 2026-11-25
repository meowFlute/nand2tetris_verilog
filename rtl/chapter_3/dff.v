module dff (
    input  wire clk,
    input  wire in,
    output reg  out
);
    /* the book discourages trying to model this with actual logic gates, so
     * we keep it as a super simple primitive. It makes sense that if you try
     * to model all the NANDs in tens of thousands of registers it'd bog
     * things down a bit potentially. We can always revisit it later */
    always @(posedge clk) begin
        out <= in;
    end
endmodule
