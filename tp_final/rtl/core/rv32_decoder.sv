`timescale 1ns / 1ps

module rv32_decoder (
    input  logic [31:0] i_instruction,

    output logic [4:0]  o_rs1,
    output logic [4:0]  o_rs2,
    output logic [4:0]  o_rd,
    output logic        o_legal,
    output logic        o_halt,
    output logic        o_uses_rs1,
    output logic        o_uses_rs2,
    output logic        o_reg_write,
    output logic        o_alu_src_imm,
    output logic [3:0]  o_alu_op,
    output logic [2:0]  o_imm_type,
    output logic        o_mem_read,
    output logic        o_mem_write,
    output logic [1:0]  o_mem_size,
    output logic        o_mem_unsigned,
    output logic [1:0]  o_branch,
    output logic [1:0]  o_jump,
    output logic [1:0]  o_wb_sel
);

    localparam logic [6:0] OPCODE_LOAD   = 7'b0000011;
    localparam logic [6:0] OPCODE_OP_IMM = 7'b0010011;
    localparam logic [6:0] OPCODE_STORE  = 7'b0100011;
    localparam logic [6:0] OPCODE_OP     = 7'b0110011;
    localparam logic [6:0] OPCODE_LUI    = 7'b0110111;
    localparam logic [6:0] OPCODE_BRANCH = 7'b1100011;
    localparam logic [6:0] OPCODE_JALR   = 7'b1100111;
    localparam logic [6:0] OPCODE_JAL    = 7'b1101111;
    localparam logic [6:0] OPCODE_SYSTEM = 7'b1110011;

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

    localparam logic [2:0] IMM_NONE = 3'd0;
    localparam logic [2:0] IMM_I    = 3'd1;
    localparam logic [2:0] IMM_S    = 3'd2;
    localparam logic [2:0] IMM_B    = 3'd3;
    localparam logic [2:0] IMM_U    = 3'd4;
    localparam logic [2:0] IMM_J    = 3'd5;

    localparam logic [1:0] MEM_BYTE = 2'd0;
    localparam logic [1:0] MEM_HALF = 2'd1;
    localparam logic [1:0] MEM_WORD = 2'd2;

    localparam logic [1:0] BR_NONE = 2'd0;
    localparam logic [1:0] BR_EQ   = 2'd1;
    localparam logic [1:0] BR_NE   = 2'd2;

    localparam logic [1:0] JUMP_NONE = 2'd0;
    localparam logic [1:0] JUMP_JAL  = 2'd1;
    localparam logic [1:0] JUMP_JALR = 2'd2;

    localparam logic [1:0] WB_ALU = 2'd0;
    localparam logic [1:0] WB_MEM = 2'd1;
    localparam logic [1:0] WB_PC4 = 2'd2;

    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;

    always_comb begin
        opcode = i_instruction[6:0];
        funct3 = i_instruction[14:12];
        funct7 = i_instruction[31:25];

        o_rs1          = i_instruction[19:15];
        o_rs2          = i_instruction[24:20];
        o_rd           = i_instruction[11:7];
        o_legal        = 1'b0;
        o_halt         = 1'b0;
        o_uses_rs1     = 1'b0;
        o_uses_rs2     = 1'b0;
        o_reg_write    = 1'b0;
        o_alu_src_imm  = 1'b0;
        o_alu_op       = ALU_ADD;
        o_imm_type     = IMM_NONE;
        o_mem_read     = 1'b0;
        o_mem_write    = 1'b0;
        o_mem_size     = MEM_WORD;
        o_mem_unsigned = 1'b0;
        o_branch       = BR_NONE;
        o_jump         = JUMP_NONE;
        o_wb_sel       = WB_ALU;

        case (opcode)
            OPCODE_OP: begin
                o_uses_rs1  = 1'b1;
                o_uses_rs2  = 1'b1;
                o_reg_write = 1'b1;
                case (funct3)
                    3'b000: begin
                        if (funct7 == 7'b0000000) begin
                            o_legal  = 1'b1;
                            o_alu_op = ALU_ADD;
                        end
                        else if (funct7 == 7'b0100000) begin
                            o_legal  = 1'b1;
                            o_alu_op = ALU_SUB;
                        end
                    end
                    3'b001: if (funct7 == 7'b0000000) begin
                        o_legal = 1'b1; o_alu_op = ALU_SLL;
                    end
                    3'b010: if (funct7 == 7'b0000000) begin
                        o_legal = 1'b1; o_alu_op = ALU_SLT;
                    end
                    3'b011: if (funct7 == 7'b0000000) begin
                        o_legal = 1'b1; o_alu_op = ALU_SLTU;
                    end
                    3'b100: if (funct7 == 7'b0000000) begin
                        o_legal = 1'b1; o_alu_op = ALU_XOR;
                    end
                    3'b101: begin
                        if (funct7 == 7'b0000000) begin
                            o_legal = 1'b1; o_alu_op = ALU_SRL;
                        end
                        else if (funct7 == 7'b0100000) begin
                            o_legal = 1'b1; o_alu_op = ALU_SRA;
                        end
                    end
                    3'b110: if (funct7 == 7'b0000000) begin
                        o_legal = 1'b1; o_alu_op = ALU_OR;
                    end
                    3'b111: if (funct7 == 7'b0000000) begin
                        o_legal = 1'b1; o_alu_op = ALU_AND;
                    end
                    default: ;
                endcase
            end

            OPCODE_OP_IMM: begin
                o_uses_rs1    = 1'b1;
                o_reg_write   = 1'b1;
                o_alu_src_imm = 1'b1;
                o_imm_type    = IMM_I;
                case (funct3)
                    3'b000: begin o_legal = 1'b1; o_alu_op = ALU_ADD;  end
                    3'b010: begin o_legal = 1'b1; o_alu_op = ALU_SLT;  end
                    3'b011: begin o_legal = 1'b1; o_alu_op = ALU_SLTU; end
                    3'b100: begin o_legal = 1'b1; o_alu_op = ALU_XOR;  end
                    3'b110: begin o_legal = 1'b1; o_alu_op = ALU_OR;   end
                    3'b111: begin o_legal = 1'b1; o_alu_op = ALU_AND;  end
                    3'b001: if (funct7 == 7'b0000000) begin
                        o_legal = 1'b1; o_alu_op = ALU_SLL;
                    end
                    3'b101: begin
                        if (funct7 == 7'b0000000) begin
                            o_legal = 1'b1; o_alu_op = ALU_SRL;
                        end
                        else if (funct7 == 7'b0100000) begin
                            o_legal = 1'b1; o_alu_op = ALU_SRA;
                        end
                    end
                    default: ;
                endcase
            end

            OPCODE_LOAD: begin
                o_uses_rs1    = 1'b1;
                o_reg_write   = 1'b1;
                o_alu_src_imm = 1'b1;
                o_alu_op      = ALU_ADD;
                o_imm_type    = IMM_I;
                o_mem_read    = 1'b1;
                o_wb_sel      = WB_MEM;
                case (funct3)
                    3'b000: begin o_legal = 1'b1; o_mem_size = MEM_BYTE; end
                    3'b001: begin o_legal = 1'b1; o_mem_size = MEM_HALF; end
                    3'b010: begin o_legal = 1'b1; o_mem_size = MEM_WORD; end
                    3'b100: begin
                        o_legal = 1'b1; o_mem_size = MEM_BYTE; o_mem_unsigned = 1'b1;
                    end
                    3'b101: begin
                        o_legal = 1'b1; o_mem_size = MEM_HALF; o_mem_unsigned = 1'b1;
                    end
                    default: ;
                endcase
            end

            OPCODE_STORE: begin
                o_uses_rs1    = 1'b1;
                o_uses_rs2    = 1'b1;
                o_alu_src_imm = 1'b1;
                o_alu_op      = ALU_ADD;
                o_imm_type    = IMM_S;
                o_mem_write   = 1'b1;
                case (funct3)
                    3'b000: begin o_legal = 1'b1; o_mem_size = MEM_BYTE; end
                    3'b001: begin o_legal = 1'b1; o_mem_size = MEM_HALF; end
                    3'b010: begin o_legal = 1'b1; o_mem_size = MEM_WORD; end
                    default: ;
                endcase
            end

            OPCODE_BRANCH: begin
                o_uses_rs1 = 1'b1;
                o_uses_rs2 = 1'b1;
                o_alu_op   = ALU_SUB;
                o_imm_type = IMM_B;
                case (funct3)
                    3'b000: begin o_legal = 1'b1; o_branch = BR_EQ; end
                    3'b001: begin o_legal = 1'b1; o_branch = BR_NE; end
                    default: ;
                endcase
            end

            OPCODE_LUI: begin
                o_legal       = 1'b1;
                o_reg_write   = 1'b1;
                o_alu_src_imm = 1'b1;
                o_alu_op      = ALU_COPY_B;
                o_imm_type    = IMM_U;
            end

            OPCODE_JAL: begin
                o_legal     = 1'b1;
                o_reg_write = 1'b1;
                o_imm_type  = IMM_J;
                o_jump      = JUMP_JAL;
                o_wb_sel    = WB_PC4;
            end

            OPCODE_JALR: begin
                if (funct3 == 3'b000) begin
                    o_legal       = 1'b1;
                    o_uses_rs1    = 1'b1;
                    o_reg_write   = 1'b1;
                    o_alu_src_imm = 1'b1;
                    o_alu_op      = ALU_ADD;
                    o_imm_type    = IMM_I;
                    o_jump        = JUMP_JALR;
                    o_wb_sel      = WB_PC4;
                end
            end

            OPCODE_SYSTEM: begin
                if (i_instruction == 32'h0010_0073) begin
                    o_legal = 1'b1;
                    o_halt  = 1'b1;
                end
            end

            default: ;
        endcase

        // Una instrucción ilegal jamás puede producir efectos laterales.
        if (!o_legal) begin
            o_halt         = 1'b0;
            o_uses_rs1     = 1'b0;
            o_uses_rs2     = 1'b0;
            o_reg_write    = 1'b0;
            o_alu_src_imm  = 1'b0;
            o_alu_op       = ALU_ADD;
            o_imm_type     = IMM_NONE;
            o_mem_read     = 1'b0;
            o_mem_write    = 1'b0;
            o_mem_size     = MEM_WORD;
            o_mem_unsigned = 1'b0;
            o_branch       = BR_NONE;
            o_jump         = JUMP_NONE;
            o_wb_sel       = WB_ALU;
        end
    end

endmodule
