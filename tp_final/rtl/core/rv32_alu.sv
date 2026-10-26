`timescale 1ns / 1ps

module rv32_alu (
    input  logic [31:0] i_a,
    input  logic [31:0] i_b,
    input  logic [3:0]  i_op,
    output logic [31:0] o_result,
    output logic        o_zero
);

    localparam logic [3:0] ALU_ADD    = 4'h0;
    localparam logic [3:0] ALU_SUB    = 4'h1;
    localparam logic [3:0] ALU_SLL    = 4'h2;
    localparam logic [3:0] ALU_SRL    = 4'h3;
    localparam logic [3:0] ALU_SRA    = 4'h4;
    localparam logic [3:0] ALU_AND    = 4'h5;
    localparam logic [3:0] ALU_OR     = 4'h6;
    localparam logic [3:0] ALU_XOR    = 4'h7;
    localparam logic [3:0] ALU_SLT    = 4'h8;
    localparam logic [3:0] ALU_SLTU   = 4'h9;
    localparam logic [3:0] ALU_COPY_B = 4'hA;

    always_comb begin
        case (i_op)
            ALU_ADD:    o_result = i_a + i_b;
            ALU_SUB:    o_result = i_a - i_b;
            ALU_SLL:    o_result = i_a << i_b[4:0];
            ALU_SRL:    o_result = i_a >> i_b[4:0];
            ALU_SRA:    o_result = $signed(i_a) >>> i_b[4:0];
            ALU_AND:    o_result = i_a & i_b;
            ALU_OR:     o_result = i_a | i_b;
            ALU_XOR:    o_result = i_a ^ i_b;
            ALU_SLT:    o_result = {31'b0, ($signed(i_a) < $signed(i_b))};
            ALU_SLTU:   o_result = {31'b0, (i_a < i_b)};
            ALU_COPY_B: o_result = i_b;
            default:    o_result = 32'h0000_0000;
        endcase
    end

    assign o_zero = (o_result == 32'h0000_0000);

endmodule
