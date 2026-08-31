`timescale 1ns / 1ps

module tb_alu;

    parameter NB_BITS = 8;

    reg  [NB_BITS-1:0] A;
    reg  [NB_BITS-1:0] B;
    reg  [5:0] op;

    wire [NB_BITS-1:0] C;

    alu #(
        .NB_BITS(NB_BITS)
    ) DUT (
        .i_A(A),
        .i_B(B),
        .i_op(op),
        .o_C(C)
    );

    initial begin

        A  = 0;
        B  = 0;
        op = 0;

        #100;

        // ADD
        A  = 8'd10;
        B  = 8'd5;
        op = 6'b100000;

        #100;

        // SUB
        A  = 8'd10;
        B  = 8'd3;
        op = 6'b100010;

        #100;

        // AND
        A  = 8'b11001100;
        B  = 8'b10101010;
        op = 6'b100100;

        #100;

        // OR
        op = 6'b100101;

        #100;

        // XOR
        op = 6'b100110;

        #100;

        $finish;

    end

endmodule