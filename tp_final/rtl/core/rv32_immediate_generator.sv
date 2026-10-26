`timescale 1ns / 1ps

module rv32_immediate_generator (
    input  logic [31:0] i_instruction,
    input  logic [2:0]  i_imm_type,
    output logic [31:0] o_immediate
);

    localparam logic [2:0] IMM_NONE = 3'd0;
    localparam logic [2:0] IMM_I    = 3'd1;
    localparam logic [2:0] IMM_S    = 3'd2;
    localparam logic [2:0] IMM_B    = 3'd3;
    localparam logic [2:0] IMM_U    = 3'd4;
    localparam logic [2:0] IMM_J    = 3'd5;

    always_comb begin
        case (i_imm_type)
            IMM_I: o_immediate = {{20{i_instruction[31]}}, i_instruction[31:20]};
            IMM_S: o_immediate = {{20{i_instruction[31]}},
                                   i_instruction[31:25], i_instruction[11:7]};
            IMM_B: o_immediate = {{19{i_instruction[31]}}, i_instruction[31],
                                   i_instruction[7], i_instruction[30:25],
                                   i_instruction[11:8], 1'b0};
            IMM_U: o_immediate = {i_instruction[31:12], 12'b0};
            IMM_J: o_immediate = {{11{i_instruction[31]}}, i_instruction[31],
                                   i_instruction[19:12], i_instruction[20],
                                   i_instruction[30:21], 1'b0};
            IMM_NONE: o_immediate = 32'h0000_0000;
            default:  o_immediate = 32'h0000_0000;
        endcase
    end

endmodule
