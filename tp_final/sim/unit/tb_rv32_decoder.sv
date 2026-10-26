`timescale 1ns / 1ps

module tb_rv32_decoder;

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

    logic [31:0] instruction;
    wire [4:0]  rs1;
    wire [4:0]  rs2;
    wire [4:0]  rd;
    wire        legal;
    wire        halt;
    wire        uses_rs1;
    wire        uses_rs2;
    wire        reg_write;
    wire        alu_src_imm;
    wire [3:0]  alu_op;
    wire [2:0]  imm_type;
    wire        mem_read;
    wire        mem_write;
    wire [1:0]  mem_size;
    wire        mem_unsigned;
    wire [1:0]  branch;
    wire [1:0]  jump;
    wire [1:0]  wb_sel;
    wire [31:0] immediate;
    integer errors;

    rv32_decoder DUT_DECODER (
        .i_instruction(instruction),
        .o_rs1(rs1), .o_rs2(rs2), .o_rd(rd),
        .o_legal(legal), .o_halt(halt),
        .o_uses_rs1(uses_rs1), .o_uses_rs2(uses_rs2),
        .o_reg_write(reg_write), .o_alu_src_imm(alu_src_imm),
        .o_alu_op(alu_op), .o_imm_type(imm_type),
        .o_mem_read(mem_read), .o_mem_write(mem_write),
        .o_mem_size(mem_size), .o_mem_unsigned(mem_unsigned),
        .o_branch(branch), .o_jump(jump), .o_wb_sel(wb_sel)
    );

    rv32_immediate_generator DUT_IMMEDIATE (
        .i_instruction(instruction), .i_imm_type(imm_type),
        .o_immediate(immediate)
    );

    function automatic logic [31:0] encode_r(
        input logic [6:0] funct7_value,
        input logic [2:0] funct3_value
    );
        encode_r = {funct7_value, 5'd2, 5'd1, funct3_value, 5'd3, 7'h33};
    endfunction

    function automatic logic [31:0] encode_i(
        input logic [11:0] imm,
        input logic [2:0]  funct3_value,
        input logic [6:0]  opcode_value
    );
        encode_i = {imm, 5'd1, funct3_value, 5'd3, opcode_value};
    endfunction

    function automatic logic [31:0] encode_s(
        input logic [11:0] imm,
        input logic [2:0]  funct3_value
    );
        encode_s = {imm[11:5], 5'd2, 5'd1, funct3_value, imm[4:0], 7'h23};
    endfunction

    function automatic logic [31:0] encode_b(
        input logic [12:0] imm,
        input logic [2:0]  funct3_value
    );
        encode_b = {imm[12], imm[10:5], 5'd2, 5'd1, funct3_value,
                    imm[4:1], imm[11], 7'h63};
    endfunction

    function automatic logic [31:0] encode_j(input logic [20:0] imm);
        encode_j = {imm[20], imm[10:1], imm[11], imm[19:12], 5'd3, 7'h6F};
    endfunction

    task automatic fail(input string name);
        begin
            errors = errors + 1;
            $display("ERROR %-12s instr=%08h status=%b alu=%h imm_type=%0d imm=%08h",
                     name, instruction,
                     {alu_src_imm, mem_write, mem_read, reg_write,
                      uses_rs2, uses_rs1, halt, legal},
                     alu_op, imm_type, immediate);
        end
    endtask

    task automatic check_r(
        input string name,
        input logic [31:0] value,
        input logic [3:0] expected_alu
    );
        begin
            instruction = value; #1;
            if (!legal || halt || !uses_rs1 || !uses_rs2 || !reg_write ||
                alu_src_imm || alu_op != expected_alu || imm_type != 3'd0 ||
                mem_read || mem_write || branch != 2'd0 || jump != 2'd0 ||
                wb_sel != 2'd0 || immediate != 32'd0 ||
                rs1 != 5'd1 || rs2 != 5'd2 || rd != 5'd3)
                fail(name);
        end
    endtask

    task automatic check_i_alu(
        input string name,
        input logic [31:0] value,
        input logic [3:0] expected_alu,
        input logic [31:0] expected_imm
    );
        begin
            instruction = value; #1;
            if (!legal || halt || !uses_rs1 || uses_rs2 || !reg_write ||
                !alu_src_imm || alu_op != expected_alu || imm_type != 3'd1 ||
                mem_read || mem_write || branch != 2'd0 || jump != 2'd0 ||
                wb_sel != 2'd0 || immediate != expected_imm ||
                rs1 != 5'd1 || rd != 5'd3)
                fail(name);
        end
    endtask

    task automatic check_load(
        input string name,
        input logic [2:0] funct3_value,
        input logic [1:0] expected_size,
        input logic expected_unsigned
    );
        begin
            instruction = encode_i(12'hFF8, funct3_value, 7'h03); #1;
            if (!legal || !uses_rs1 || uses_rs2 || !reg_write ||
                !alu_src_imm || alu_op != ALU_ADD || imm_type != 3'd1 ||
                !mem_read || mem_write || mem_size != expected_size ||
                mem_unsigned != expected_unsigned || wb_sel != 2'd1 ||
                immediate != 32'hFFFF_FFF8)
                fail(name);
        end
    endtask

    task automatic check_store(
        input string name,
        input logic [2:0] funct3_value,
        input logic [1:0] expected_size
    );
        begin
            instruction = encode_s(12'hFF4, funct3_value); #1;
            if (!legal || !uses_rs1 || !uses_rs2 || reg_write ||
                !alu_src_imm || alu_op != ALU_ADD || imm_type != 3'd2 ||
                mem_read || !mem_write || mem_size != expected_size ||
                immediate != 32'hFFFF_FFF4)
                fail(name);
        end
    endtask

    task automatic check_branch(
        input string name,
        input logic [2:0] funct3_value,
        input logic [1:0] expected_branch
    );
        begin
            instruction = encode_b(13'h1FFC, funct3_value); #1;
            if (!legal || !uses_rs1 || !uses_rs2 || reg_write ||
                alu_src_imm || alu_op != ALU_SUB || imm_type != 3'd3 ||
                mem_read || mem_write || branch != expected_branch ||
                jump != 2'd0 || immediate != 32'hFFFF_FFFC)
                fail(name);
        end
    endtask

    task automatic check_illegal(input string name, input logic [31:0] value);
        begin
            instruction = value; #1;
            if (legal || halt || uses_rs1 || uses_rs2 || reg_write ||
                alu_src_imm || mem_read || mem_write || branch != 2'd0 ||
                jump != 2'd0 || imm_type != 3'd0 || immediate != 32'd0)
                fail(name);
        end
    endtask

    initial begin
        errors = 0;
        instruction = 32'd0;

        check_r("ADD",  encode_r(7'h00, 3'b000), ALU_ADD);
        check_r("SUB",  encode_r(7'h20, 3'b000), ALU_SUB);
        check_r("SLL",  encode_r(7'h00, 3'b001), ALU_SLL);
        check_r("SLT",  encode_r(7'h00, 3'b010), ALU_SLT);
        check_r("SLTU", encode_r(7'h00, 3'b011), ALU_SLTU);
        check_r("XOR",  encode_r(7'h00, 3'b100), ALU_XOR);
        check_r("SRL",  encode_r(7'h00, 3'b101), ALU_SRL);
        check_r("SRA",  encode_r(7'h20, 3'b101), ALU_SRA);
        check_r("OR",   encode_r(7'h00, 3'b110), ALU_OR);
        check_r("AND",  encode_r(7'h00, 3'b111), ALU_AND);

        check_i_alu("ADDI",  encode_i(12'hFF0, 3'b000, 7'h13), ALU_ADD,  32'hFFFF_FFF0);
        check_i_alu("SLTI",  encode_i(12'h055, 3'b010, 7'h13), ALU_SLT,  32'h0000_0055);
        check_i_alu("SLTIU", encode_i(12'h055, 3'b011, 7'h13), ALU_SLTU, 32'h0000_0055);
        check_i_alu("XORI",  encode_i(12'h055, 3'b100, 7'h13), ALU_XOR,  32'h0000_0055);
        check_i_alu("ORI",   encode_i(12'h055, 3'b110, 7'h13), ALU_OR,   32'h0000_0055);
        check_i_alu("ANDI",  encode_i(12'h055, 3'b111, 7'h13), ALU_AND,  32'h0000_0055);
        check_i_alu("SLLI",  encode_i(12'h003, 3'b001, 7'h13), ALU_SLL,  32'h0000_0003);
        check_i_alu("SRLI",  encode_i(12'h003, 3'b101, 7'h13), ALU_SRL,  32'h0000_0003);
        check_i_alu("SRAI",  encode_i(12'h403, 3'b101, 7'h13), ALU_SRA,  32'h0000_0403);

        check_load("LB",  3'b000, 2'd0, 1'b0);
        check_load("LH",  3'b001, 2'd1, 1'b0);
        check_load("LW",  3'b010, 2'd2, 1'b0);
        check_load("LBU", 3'b100, 2'd0, 1'b1);
        check_load("LHU", 3'b101, 2'd1, 1'b1);

        check_store("SB", 3'b000, 2'd0);
        check_store("SH", 3'b001, 2'd1);
        check_store("SW", 3'b010, 2'd2);
        check_branch("BEQ", 3'b000, 2'd1);
        check_branch("BNE", 3'b001, 2'd2);

        instruction = {20'hABCDE, 5'd3, 7'h37}; #1;
        if (!legal || !reg_write || !alu_src_imm || alu_op != ALU_COPY_B ||
            imm_type != 3'd4 || immediate != 32'hABCDE000 || wb_sel != 2'd0)
            fail("LUI");

        instruction = encode_j(21'h1F_FFF8); #1;
        if (!legal || !reg_write || imm_type != 3'd5 || jump != 2'd1 ||
            wb_sel != 2'd2 || immediate != 32'hFFFF_FFF8)
            fail("JAL");

        instruction = encode_i(12'h00C, 3'b000, 7'h67); #1;
        if (!legal || !uses_rs1 || !reg_write || !alu_src_imm ||
            imm_type != 3'd1 || jump != 2'd2 || wb_sel != 2'd2 ||
            immediate != 32'h0000_000C)
            fail("JALR");

        instruction = 32'h0010_0073; #1;
        if (!legal || !halt || uses_rs1 || uses_rs2 || reg_write ||
            mem_read || mem_write || jump != 2'd0 || branch != 2'd0)
            fail("EBREAK");

        check_illegal("OP FUNCT7", encode_r(7'h7F, 3'b000));
        check_illegal("LOAD F3", encode_i(12'h000, 3'b011, 7'h03));
        check_illegal("ECALL", 32'h0000_0073);
        check_illegal("ZERO", 32'h0000_0000);

        if (errors == 0)
            $display("RESULTADO: DECODER E INMEDIATOS RV32I OK");
        else
            $fatal(1, "RESULTADO: %0d ERRORES", errors);

        $finish;
    end

endmodule
