`timescale 1ns / 1ps

module tb_rv32_alu;

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

    logic [31:0] a;
    logic [31:0] b;
    logic [3:0]  op;
    logic [31:0] result;
    logic        zero;
    integer      errors;

    rv32_alu DUT (
        .i_a(a),
        .i_b(b),
        .i_op(op),
        .o_result(result),
        .o_zero(zero)
    );

    task automatic check;
        input [3:0]  test_op;
        input [31:0] test_a;
        input [31:0] test_b;
        input [31:0] expected;
        begin
            op = test_op;
            a  = test_a;
            b  = test_b;
            #1;
            if (result !== expected) begin
                errors = errors + 1;
                $display("ERROR op=%h A=%h B=%h esperado=%h obtenido=%h",
                         test_op, test_a, test_b, expected, result);
            end
            if (zero !== (expected == 32'h0000_0000)) begin
                errors = errors + 1;
                $display("ERROR flag zero para resultado=%h", expected);
            end
        end
    endtask

    initial begin
        errors = 0;
        a = 0;
        b = 0;
        op = 0;

        check(ALU_ADD,    32'd10,        32'd5,         32'd15);
        check(ALU_ADD,    32'hFFFF_FFFF, 32'd1,         32'h0000_0000);
        check(ALU_SUB,    32'd10,        32'd3,         32'd7);
        check(ALU_SUB,    32'd3,         32'd10,        32'hFFFF_FFF9);
        check(ALU_SLL,    32'h0000_0001, 32'd31,        32'h8000_0000);
        check(ALU_SRL,    32'h8000_0000, 32'd1,         32'h4000_0000);
        check(ALU_SRA,    32'h8000_0000, 32'd1,         32'hC000_0000);
        check(ALU_AND,    32'hAA55_F00F, 32'h0FF0_55AA, 32'h0A50_500A);
        check(ALU_OR,     32'hAA55_F00F, 32'h0FF0_55AA, 32'hAFF5_F5AF);
        check(ALU_XOR,    32'hAA55_F00F, 32'h0FF0_55AA, 32'hA5A5_A5A5);
        check(ALU_SLT,    32'hFFFF_FFFF, 32'h0000_0001, 32'h0000_0001);
        check(ALU_SLT,    32'h7FFF_FFFF, 32'h8000_0000, 32'h0000_0000);
        check(ALU_SLTU,   32'hFFFF_FFFF, 32'h0000_0001, 32'h0000_0000);
        check(ALU_SLTU,   32'h0000_0001, 32'hFFFF_FFFF, 32'h0000_0001);
        check(ALU_COPY_B, 32'hDEAD_BEEF, 32'h1234_5678, 32'h1234_5678);

        if (errors == 0)
            $display("RESULTADO: ALU RV32 OK");
        else
            $fatal(1, "RESULTADO: ALU RV32 CON %0d ERRORES", errors);

        $finish;
    end

endmodule
