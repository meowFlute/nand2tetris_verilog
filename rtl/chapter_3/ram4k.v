module ram4k (
    input  wire        clk,
    input  wire [15:0] in,
    input  wire [11:0] address,
    input  wire        load,
    output wire [15:0] out
);
    reg [15:0] mem [0:4095];

    // synchronous write
    always @(posedge clk) begin
        if (load)
            mem[address] <= in;
    end

    // combinational read, same as the structural versions
    assign out = mem[address];
endmodule
