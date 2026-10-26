`timescale 1ns / 1ps

module tb_rv32_pipeline_rv32i;

    logic clk, rst, start, enable;
    logic [31:0] program_words;
    logic imem_read_enable, imem_read_misaligned, imem_read_out_of_range;
    logic [31:0] imem_read_addr, imem_read_data;
    logic imem_write_enable;
    logic [31:0] imem_write_addr, imem_write_data;
    logic dmem_read_enable, dmem_read_unsigned;
    logic [31:0] dmem_read_addr, dmem_read_data;
    logic [1:0] dmem_read_size;
    logic dmem_read_misaligned, dmem_read_out_of_range;
    logic dmem_write_enable;
    logic [31:0] dmem_write_addr, dmem_write_data;
    logic [1:0] dmem_write_size;
    logic dmem_write_misaligned, dmem_write_out_of_range;
    logic debug_dmem;
    logic [31:0] debug_dmem_addr;
    logic [4:0] debug_reg_addr;
    logic [31:0] debug_reg_data;
    logic running, halted;
    logic [3:0] stop_cause, pipeline_valid;
    logic [31:0] pc, cycles, retired;
    integer errors, timeout_cycles, redirect_count, stall_count;

    wire mux_dmem_read_enable = debug_dmem ? 1'b1 : dmem_read_enable;
    wire [31:0] mux_dmem_read_addr = debug_dmem ? debug_dmem_addr
                                                 : dmem_read_addr;
    wire [1:0] mux_dmem_read_size = debug_dmem ? 2'd2 : dmem_read_size;
    wire mux_dmem_read_unsigned = debug_dmem ? 1'b0 : dmem_read_unsigned;

    rv32_pipeline_core DUT (
        .i_clk(clk), .i_rst(rst), .i_start(start), .i_enable(enable),
        .i_program_words(program_words),
        .o_imem_read_enable(imem_read_enable),
        .o_imem_read_addr(imem_read_addr),
        .i_imem_read_data(imem_read_data),
        .i_imem_read_misaligned(imem_read_misaligned),
        .i_imem_read_out_of_range(imem_read_out_of_range),
        .o_dmem_read_enable(dmem_read_enable),
        .o_dmem_read_addr(dmem_read_addr), .o_dmem_read_size(dmem_read_size),
        .o_dmem_read_unsigned(dmem_read_unsigned),
        .i_dmem_read_data(dmem_read_data),
        .i_dmem_read_misaligned(dmem_read_misaligned),
        .i_dmem_read_out_of_range(dmem_read_out_of_range),
        .o_dmem_write_enable(dmem_write_enable),
        .o_dmem_write_addr(dmem_write_addr),
        .o_dmem_write_size(dmem_write_size),
        .o_dmem_write_data(dmem_write_data),
        .i_dmem_write_misaligned(dmem_write_misaligned),
        .i_dmem_write_out_of_range(dmem_write_out_of_range),
        .i_debug_reg_addr(debug_reg_addr),
        .o_debug_reg_data(debug_reg_data),
        .o_running(running), .o_halted(halted),
        .o_stop_cause(stop_cause), .o_pc(pc),
        .o_cycle_count(cycles), .o_retired_count(retired),
        .o_pipeline_valid(pipeline_valid)
    );

    rv32_instruction_memory #(.WORDS(1024)) IMEM (
        .i_clk(clk), .i_rst(rst), .i_read_enable(imem_read_enable),
        .i_read_addr(imem_read_addr), .o_read_data(imem_read_data),
        .o_read_misaligned(imem_read_misaligned),
        .o_read_out_of_range(imem_read_out_of_range),
        .i_write_enable(imem_write_enable), .i_write_addr(imem_write_addr),
        .i_write_data(imem_write_data), .o_write_misaligned(),
        .o_write_out_of_range()
    );

    rv32_data_memory #(.WORDS(1024)) DMEM (
        .i_clk(clk), .i_rst(rst), .i_read_enable(mux_dmem_read_enable),
        .i_read_addr(mux_dmem_read_addr), .i_read_size(mux_dmem_read_size),
        .i_read_unsigned(mux_dmem_read_unsigned),
        .o_read_data(dmem_read_data),
        .o_read_misaligned(dmem_read_misaligned),
        .o_read_out_of_range(dmem_read_out_of_range),
        .i_write_enable(dmem_write_enable), .i_write_addr(dmem_write_addr),
        .i_write_size(dmem_write_size), .i_write_data(dmem_write_data),
        .o_write_misaligned(dmem_write_misaligned),
        .o_write_out_of_range(dmem_write_out_of_range)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    always @(posedge clk) begin
        if (rst) begin
            redirect_count <= 0;
            stall_count <= 0;
        end
        else if (running) begin
            if (DUT.ex_redirect)
                redirect_count <= redirect_count + 1;
            if (DUT.load_use_hazard)
                stall_count <= stall_count + 1;
        end
    end

    task automatic write_instruction(input integer word_index,
                                     input logic [31:0] instruction);
        begin
            @(negedge clk);
            imem_write_addr = word_index * 4;
            imem_write_data = instruction;
            imem_write_enable = 1'b1;
            @(posedge clk);
            #1 imem_write_enable = 1'b0;
        end
    endtask

    task automatic check_register(input logic [4:0] address,
                                  input logic [31:0] expected);
        begin
            debug_reg_addr = address;
            #1;
            if (debug_reg_data !== expected) begin
                errors = errors + 1;
                $display("ERROR x%0d esperado=%h obtenido=%h",
                         address, expected, debug_reg_data);
            end
            else
                $display("OK    x%0d=%h", address, debug_reg_data);
        end
    endtask

    initial begin
        rst = 1'b1; start = 1'b0; enable = 1'b1;
        program_words = 32'd52;
        imem_write_enable = 1'b0; imem_write_addr = 0; imem_write_data = 0;
        debug_dmem = 1'b0; debug_dmem_addr = 0; debug_reg_addr = 0;
        errors = 0; redirect_count = 0; stall_count = 0;

        repeat (2) @(posedge clk);
        @(negedge clk); rst = 1'b0;

        write_instruction(0,  32'h00500093);
        write_instruction(1,  32'hFF800113);
        write_instruction(2,  32'h002081B3);
        write_instruction(3,  32'h40208233);
        write_instruction(4,  32'h001092B3);
        write_instruction(5,  32'h00115333);
        write_instruction(6,  32'h401153B3);
        write_instruction(7,  32'h0020F433);
        write_instruction(8,  32'h0020E4B3);
        write_instruction(9,  32'h0020C533);
        write_instruction(10, 32'h001125B3);
        write_instruction(11, 32'h00113633);
        write_instruction(12, 32'h00F4F693);
        write_instruction(13, 32'h05546713);
        write_instruction(14, 32'h0FF74793);
        write_instruction(15, 32'h00012813);
        write_instruction(16, 32'h0060B893);
        write_instruction(17, 32'h00309913);
        write_instruction(18, 32'h00215993);
        write_instruction(19, 32'h40215A13);
        write_instruction(20, 32'hABCDEAB7);
        write_instruction(21, 32'hF8000B13);
        write_instruction(22, 32'h01502023);
        write_instruction(23, 32'h016000A3);
        write_instruction(24, 32'h00F01123);
        write_instruction(25, 32'h00100B83);
        write_instruction(26, 32'h00104C03);
        write_instruction(27, 32'h00201C83);
        write_instruction(28, 32'h00205D03);
        write_instruction(29, 32'h00002D83);
        write_instruction(30, 32'h016B8663);
        write_instruction(31, 32'h06300E13);
        write_instruction(32, 32'h05800E13);
        write_instruction(33, 32'h00100E13);
        write_instruction(34, 32'h00209663);
        write_instruction(35, 32'h04D00E13);
        write_instruction(36, 32'h04200E13);
        write_instruction(37, 32'h001E0E13);
        write_instruction(38, 32'h00208463);
        write_instruction(39, 32'h001E0E13);
        write_instruction(40, 32'h00109463);
        write_instruction(41, 32'h001E0E13);
        write_instruction(42, 32'h00C00EEF);
        write_instruction(43, 32'h03700E13);
        write_instruction(44, 32'h03800E13);
        write_instruction(45, 32'h001E0E13);
        write_instruction(46, 32'h0C800F13);
        write_instruction(47, 32'h000F0FE7);
        write_instruction(48, 32'h02C00E13);
        write_instruction(49, 32'h02D00E13);
        write_instruction(50, 32'h001E0E13);
        write_instruction(51, 32'h00100073);

        @(negedge clk); start = 1'b1;
        @(posedge clk); #1 start = 1'b0;

        timeout_cycles = 0;
        while (!halted && timeout_cycles < 300) begin
            @(posedge clk);
            timeout_cycles = timeout_cycles + 1;
        end
        #1;

        if (!halted) begin errors = errors + 1; $display("ERROR timeout"); end
        if (stop_cause !== 4'd1) begin
            errors = errors + 1;
            $display("ERROR causa=%0d, se esperaba HALT", stop_cause);
        end
        if (pipeline_valid !== 4'b0000) begin
            errors = errors + 1; $display("ERROR pipeline=%b", pipeline_valid);
        end

        check_register(0,  32'h00000000);
        check_register(1,  32'h00000005);
        check_register(2,  32'hFFFFFFF8);
        check_register(3,  32'hFFFFFFFD);
        check_register(4,  32'h0000000D);
        check_register(5,  32'h000000A0);
        check_register(6,  32'h07FFFFFF);
        check_register(7,  32'hFFFFFFFF);
        check_register(8,  32'h00000000);
        check_register(9,  32'hFFFFFFFD);
        check_register(10, 32'hFFFFFFFD);
        check_register(11, 32'h00000001);
        check_register(12, 32'h00000000);
        check_register(13, 32'h0000000D);
        check_register(14, 32'h00000055);
        check_register(15, 32'h000000AA);
        check_register(16, 32'h00000001);
        check_register(17, 32'h00000001);
        check_register(18, 32'h00000028);
        check_register(19, 32'h3FFFFFFE);
        check_register(20, 32'hFFFFFFFE);
        check_register(21, 32'hABCDE000);
        check_register(22, 32'hFFFFFF80);
        check_register(23, 32'hFFFFFF80);
        check_register(24, 32'h00000080);
        check_register(25, 32'h000000AA);
        check_register(26, 32'h000000AA);
        check_register(27, 32'h00AA8000);
        check_register(28, 32'h00000006);
        check_register(29, 32'h000000AC);
        check_register(30, 32'h000000C8);
        check_register(31, 32'h000000C0);

        debug_dmem_addr = 0; debug_dmem = 1'b1;
        @(negedge clk); #1;
        if (dmem_read_data !== 32'h00AA8000) begin
            errors = errors + 1;
            $display("ERROR DMEM[0]=%h esperado=00AA8000", dmem_read_data);
        end
        else $display("OK    DMEM[0]=%h", dmem_read_data);

        if (redirect_count != 4) begin
            errors = errors + 1;
            $display("ERROR redirects esperados=4 obtenidos=%0d", redirect_count);
        end
        else $display("OK    redirects=%0d", redirect_count);
        if (stall_count != 0) begin
            errors = errors + 1;
            $display("ERROR stalls inesperados=%0d", stall_count);
        end
        if (retired !== 32'd43) begin
            errors = errors + 1;
            $display("ERROR retiradas esperadas=43 obtenidas=%0d", retired);
        end

        $display("INFO  ciclos=%0d retiradas=%0d pc=%h", cycles, retired, pc);
        if (errors == 0)
            $display("RESULTADO: COBERTURA RV32I PIPELINE OK");
        else
            $fatal(1, "RESULTADO: COBERTURA RV32I CON %0d ERRORES", errors);
        $finish;
    end
endmodule
