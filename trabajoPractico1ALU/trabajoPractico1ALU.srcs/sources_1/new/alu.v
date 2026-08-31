`timescale 1ns / 1ps

module alu #(
    parameter NB_BITS = 8
)(
    input  wire [NB_BITS-1:0] i_A,
    input  wire [NB_BITS-1:0] i_B,
    input  wire [5:0]         i_op,

    output reg  [NB_BITS-1:0] o_C,
    output reg                o_zero,
    output reg                o_carry,
    output reg                o_overflow
);

    reg [NB_BITS:0] aux;

    always @(*) begin

        o_C        = {NB_BITS{1'b0}};
        o_carry    = 1'b0;
        o_overflow = 1'b0;
        aux        = {(NB_BITS+1){1'b0}};

        case (i_op)

            // ADD
            6'b100000: begin
                aux = {1'b0, i_A} + {1'b0, i_B};

                o_C     = aux[NB_BITS-1:0];
                o_carry = aux[NB_BITS];

                o_overflow =
                    (~(i_A[NB_BITS-1] ^ i_B[NB_BITS-1])) &
                     (o_C[NB_BITS-1] ^ i_A[NB_BITS-1]);
            end

            // SUB
            6'b100010: begin
                aux = {1'b0, i_A}
                    + {1'b0, ~i_B}
                    + 1'b1;

                o_C     = aux[NB_BITS-1:0];
                o_carry = aux[NB_BITS];

                o_overflow =
                    (i_A[NB_BITS-1] ^ i_B[NB_BITS-1]) &
                    (o_C[NB_BITS-1] ^ i_A[NB_BITS-1]);
            end

            // AND
            6'b100100: begin
                o_C = i_A & i_B;
            end

            // OR
            6'b100101: begin
                o_C = i_A | i_B;
            end

            // XOR
            6'b100110: begin
                o_C = i_A ^ i_B;
            end

            // SRA
            6'b000011: begin
                o_C = $signed(i_A) >>> i_B;
            end

            // SRL
            6'b000010: begin
                o_C = i_A >> i_B;
            end

            // NOR
            6'b100111: begin
                o_C = ~(i_A | i_B);
            end

            default: begin
                o_C = {NB_BITS{1'b0}};
            end

        endcase

        o_zero = (o_C == {NB_BITS{1'b0}});

    end

endmodule