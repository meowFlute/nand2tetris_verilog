module cpu (
    input         clk,
    input  [15:0] inM,          // M value input (RAM[A])
    input  [15:0] instruction,
    input         reset,
    output [15:0] outM,         // M value output
    output        writeM,
    output [14:0] addressM,
    output [14:0] pc
);
    wire [15:0] a_in, a_out, d_out, alu_y, alu_out, pc_out;
    wire is_a_instr, load_a, load_d, zr, ng;
    wire zr_or_ng, pos, jlt, jeq, jgt, jle, jump_cond, jump;

    // ---- A register ----
    mux16 mux_a_in (.a(instruction), .b(alu_out), .sel(instruction[15]), .out(a_in));
    not_gate n_is_a (.in(instruction[15]), .out(is_a_instr));
    or_gate  or_load_a (.a(is_a_instr), .b(instruction[5]), .out(load_a));
    register16 reg_a (.clk(clk), .in(a_in), .load(load_a), .out(a_out));

    // ---- D register ----
    and_gate and_load_d (.a(instruction[15]), .b(instruction[4]), .out(load_d));
    register16 reg_d (.clk(clk), .in(alu_out), .load(load_d), .out(d_out));

    // ---- ALU ----
    mux16 mux_alu_y (.a(a_out), .b(inM), .sel(instruction[12]), .out(alu_y));
    alu alu0 (
        .x(d_out), .y(alu_y),
        .zx(instruction[11]), .nx(instruction[10]),
        .zy(instruction[9]),  .ny(instruction[8]),
        .f(instruction[7]),   .no(instruction[6]),
        .out(alu_out), .zr(zr), .ng(ng)
    );

    // ---- Outputs to memory ----
    assign outM     = alu_out;
    assign addressM = a_out[14:0];
    and_gate and_write_m (.a(instruction[15]), .b(instruction[3]), .out(writeM));

    // ---- Jump logic ----
    or_gate  or_zr_ng (.a(zr), .b(ng), .out(zr_or_ng));
    not_gate n_pos    (.in(zr_or_ng), .out(pos));              // out > 0
    and_gate and_jlt  (.a(instruction[2]), .b(ng),  .out(jlt));
    and_gate and_jeq  (.a(instruction[1]), .b(zr),  .out(jeq));
    and_gate and_jgt  (.a(instruction[0]), .b(pos), .out(jgt));
    or_gate  or_jle   (.a(jlt), .b(jeq), .out(jle));
    or_gate  or_jcond (.a(jle), .b(jgt), .out(jump_cond));
    and_gate and_jump (.a(instruction[15]), .b(jump_cond), .out(jump)); // only C-instructions jump

    // ---- Program counter ----
    pc pc0 (.clk(clk), .in(a_out), .load(jump), .inc(1'b1), .reset(reset), .out(pc_out));
    assign pc = pc_out[14:0];
endmodule
