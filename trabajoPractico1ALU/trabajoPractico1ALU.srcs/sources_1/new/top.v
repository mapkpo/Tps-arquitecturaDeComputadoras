`timescale 1ns / 1ps

module top #(
    parameter NB_BITS = 8
)(
    input wire                  i_clk,

    input wire [NB_BITS-1:0]    i_switches,

    input wire                  i_btn_A,
    input wire                  i_btn_B,
    input wire                  i_btn_OP,

    output wire [NB_BITS-1:0]   o_leds,

    output wire                 o_zero,
    output wire                 o_carry,
    output wire                 o_overflow
);

    wire [NB_BITS-1:0] A;
    wire [NB_BITS-1:0] B;
    wire [5:0] op;


    // ============================
    // REGISTRO A
    // ============================

    reg_nbits #(
        .NB_BITS(NB_BITS)
    ) REG_A (
        .i_clk(i_clk),
        .i_enable(i_btn_A),
        .i_D(i_switches),
        .o_Q(A)
    );


    // ============================
    // REGISTRO B
    // ============================

    reg_nbits #(
        .NB_BITS(NB_BITS)
    ) REG_B (
        .i_clk(i_clk),
        .i_enable(i_btn_B),
        .i_D(i_switches),
        .o_Q(B)
    );


    // ============================
    // REGISTRO OP
    // ============================

    reg_nbits #(
        .NB_BITS(6)
    ) REG_OP (
        .i_clk(i_clk),
        .i_enable(i_btn_OP),
        .i_D(i_switches[5:0]),
        .o_Q(op)
    );


    // ============================
    // ALU
    // ============================

    alu #(
        .NB_BITS(NB_BITS)
    ) ALU (
        .i_A(A),
        .i_B(B),
        .i_op(op),

        .o_C(o_leds),
        .o_zero(o_zero),
        .o_carry(o_carry),
        .o_overflow(o_overflow)
    );

endmodule