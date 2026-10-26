`timescale 1ns / 1ps

module tb_rv32_pipeline_basic;

    logic clk;
    logic rst;
    logic start;
    logic enable;
    logic [31:0] program_words;

    logic core_imem_read_enable;
    logic [31:0] core_imem_read_addr;
    logic [31:0] imem_read_data;
    logic imem_read_misaligned;
    logic imem_read_out_of_range;
    logic imem_write_enable;
    logic [31:0] imem_write_addr;
    logic [31:0] imem_write_data;

    logic core_dmem_read_enable;
    logic [31:0] core_dmem_read_addr;
    logic [1:0] core_dmem_read_size;
    logic core_dmem_read_unsigned;
    logic core_dmem_write_enable;
    logic [31:0] core_dmem_write_addr;
    logic [1:0] core_dmem_write_size;
    logic [31:0] core_dmem_write_data;
    logic [31:0] dmem_read_data;
    logic dmem_read_misaligned;
    logic dmem_read_out_of_range;
    logic dmem_write_misaligned;
    logic dmem_write_out_of_range;

    logic debug_dmem;
    logic [31:0] debug_dmem_addr;
    logic [4:0] debug_reg_addr;
    logic [31:0] debug_reg_data;
    logic running;
    logic halted;
    logic [3:0] stop_cause;
    logic [31:0] pc;
    logic [31:0] cycles;
    logic [31:0] retired;
    logic [3:0] pipeline_valid;
    integer errors;
    integer timeout_cycles;
    integer stall_count;

    wire dmem_read_enable = debug_dmem ? 1'b1 : core_dmem_read_enable;
    wire [31:0] dmem_read_addr = debug_dmem ? debug_dmem_addr
                                             : core_dmem_read_addr;
    wire [1:0] dmem_read_size = debug_dmem ? 2'd2 : core_dmem_read_size;
    wire dmem_read_unsigned = debug_dmem ? 1'b0 : core_dmem_read_unsigned;

    rv32_pipeline_core DUT (
        .i_clk(clk), .i_rst(rst), .i_start(start), .i_enable(enable),
        .i_program_words(program_words),
        .o_imem_read_enable(core_imem_read_enable),
        .o_imem_read_addr(core_imem_read_addr),
        .i_imem_read_data(imem_read_data),
        .i_imem_read_misaligned(imem_read_misaligned),
        .i_imem_read_out_of_range(imem_read_out_of_range),
        .o_dmem_read_enable(core_dmem_read_enable),
        .o_dmem_read_addr(core_dmem_read_addr),
        .o_dmem_read_size(core_dmem_read_size),
        .o_dmem_read_unsigned(core_dmem_read_unsigned),
        .i_dmem_read_data(dmem_read_data),
        .i_dmem_read_misaligned(dmem_read_misaligned),
        .i_dmem_read_out_of_range(dmem_read_out_of_range),
        .o_dmem_write_enable(core_dmem_write_enable),
        .o_dmem_write_addr(core_dmem_write_addr),
        .o_dmem_write_size(core_dmem_write_size),
        .o_dmem_write_data(core_dmem_write_data),
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
        .i_clk(clk), .i_rst(rst),
        .i_read_enable(core_imem_read_enable),
        .i_read_addr(core_imem_read_addr),
        .o_read_data(imem_read_data),
        .o_read_misaligned(imem_read_misaligned),
        .o_read_out_of_range(imem_read_out_of_range),
        .i_write_enable(imem_write_enable),
        .i_write_addr(imem_write_addr),
        .i_write_data(imem_write_data),
        .o_write_misaligned(), .o_write_out_of_range()
    );

    rv32_data_memory #(.WORDS(1024)) DMEM (
        .i_clk(clk), .i_rst(rst),
        .i_read_enable(dmem_read_enable), .i_read_addr(dmem_read_addr),
        .i_read_size(dmem_read_size), .i_read_unsigned(dmem_read_unsigned),
        .o_read_data(dmem_read_data),
        .o_read_misaligned(dmem_read_misaligned),
        .o_read_out_of_range(dmem_read_out_of_range),
        .i_write_enable(core_dmem_write_enable),
        .i_write_addr(core_dmem_write_addr),
        .i_write_size(core_dmem_write_size),
        .i_write_data(core_dmem_write_data),
        .o_write_misaligned(dmem_write_misaligned),
        .o_write_out_of_range(dmem_write_out_of_range)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    always @(posedge clk) begin
        if (rst)
            stall_count <= 0;
        else if (running && DUT.load_use_hazard)
            stall_count <= stall_count + 1;
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

    task automatic write_nops(input integer first_word, input integer count);
        integer index;
        begin
            for (index = 0; index < count; index = index + 1)
                write_instruction(first_word + index, 32'h0000_0013);
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
        rst = 1'b1;
        start = 1'b0;
        enable = 1'b1;
        program_words = 32'd18;
        imem_write_enable = 1'b0;
        imem_write_addr = 32'd0;
        imem_write_data = 32'd0;
        debug_dmem = 1'b0;
        debug_dmem_addr = 32'd0;
        debug_reg_addr = 5'd0;
        errors = 0;
        stall_count = 0;

        repeat (2) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;

        write_instruction(0,  32'h0050_0093); // addi x1,x0,5
        write_instruction(1,  32'h0070_8113); // addi x2,x1,7 (EX/MEM)
        write_instruction(2,  32'h0011_01B3); // add x3,x2,x1 (doble forwarding)
        write_instruction(3,  32'h0030_2023); // sw x3,0(x0) (store forwarding)
        write_instruction(4,  32'h0000_2203); // lw x4,0(x0)
        write_instruction(5,  32'hFFE2_0293); // addi x5,x4,-2 (load-use)
        write_instruction(6,  32'h0042_8333); // add x6,x5,x4
        write_instruction(7,  32'h0200_0393); // addi x7,x0,32
        write_instruction(8,  32'h0073_0663); // beq x6,x7,+12
        write_instruction(9,  32'h0630_0413); // wrong path
        write_instruction(10, 32'h0580_0413); // wrong path
        write_instruction(11, 32'h02A0_0413); // addi x8,x0,42
        write_instruction(12, 32'h0080_2223); // sw x8,4(x0)
        write_instruction(13, 32'h0040_2483); // lw x9,4(x0)
        write_instruction(14, 32'h0090_2423); // sw x9,8(x0) (load-use store)
        write_instruction(15, 32'h0080_2503); // lw x10,8(x0)
        write_instruction(16, 32'h0015_0593); // addi x11,x10,1 (load-use)
        write_instruction(17, 32'h0010_0073); // ebreak

        @(negedge clk);
        start = 1'b1;
        @(posedge clk);
        #1 start = 1'b0;

        timeout_cycles = 0;
        while (!halted && timeout_cycles < 200) begin
            @(posedge clk);
            timeout_cycles = timeout_cycles + 1;
        end
        #1;

        if (!halted) begin
            errors = errors + 1;
            $display("ERROR timeout: el core no se detuvo");
        end
        if (stop_cause !== 4'd1) begin
            errors = errors + 1;
            $display("ERROR causa esperada HALT=1, obtenida=%0d", stop_cause);
        end
        if (pipeline_valid !== 4'b0000) begin
            errors = errors + 1;
            $display("ERROR pipeline no vacío: %b", pipeline_valid);
        end

        check_register(5'd0, 32'd0);
        check_register(5'd1, 32'd5);
        check_register(5'd2, 32'd12);
        check_register(5'd3, 32'd17);
        check_register(5'd4, 32'd17);
        check_register(5'd5, 32'd15);
        check_register(5'd6, 32'd32);
        check_register(5'd7, 32'd32);
        check_register(5'd8, 32'd42);
        check_register(5'd9, 32'd42);
        check_register(5'd10, 32'd42);
        check_register(5'd11, 32'd43);

        debug_dmem_addr = 32'd0;
        debug_dmem = 1'b1;
        @(negedge clk);
        #1;
        if (dmem_read_data !== 32'd17) begin
            errors = errors + 1;
            $display("ERROR DMEM[0] esperado=00000011 obtenido=%h",
                     dmem_read_data);
        end
        else
            $display("OK    DMEM[0]=%h", dmem_read_data);

        debug_dmem_addr = 32'd4;
        @(negedge clk); #1;
        if (dmem_read_data !== 32'd42) begin
            errors = errors + 1;
            $display("ERROR DMEM[4] esperado=0000002A obtenido=%h",
                     dmem_read_data);
        end
        else
            $display("OK    DMEM[4]=%h", dmem_read_data);

        debug_dmem_addr = 32'd8;
        @(negedge clk); #1;
        if (dmem_read_data !== 32'd42) begin
            errors = errors + 1;
            $display("ERROR DMEM[8] esperado=0000002A obtenido=%h",
                     dmem_read_data);
        end
        else
            $display("OK    DMEM[8]=%h", dmem_read_data);

        if (stall_count != 3) begin
            errors = errors + 1;
            $display("ERROR stalls esperados=3 obtenidos=%0d", stall_count);
        end
        else
            $display("OK    stalls load-use=%0d", stall_count);

        $display("INFO  ciclos=%0d retiradas=%0d pc=%h",
                 cycles, retired, pc);
        if (errors == 0)
            $display("RESULTADO: PIPELINE RV32 HAZARDS OK");
        else
            $fatal(1, "RESULTADO: PIPELINE RV32 HAZARDS CON %0d ERRORES", errors);
        $finish;
    end

endmodule
