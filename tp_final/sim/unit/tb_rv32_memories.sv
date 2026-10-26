`timescale 1ns / 1ps

module tb_rv32_memories;

    logic clk;
    logic rst;

    logic        imem_read_enable;
    logic [31:0] imem_read_addr;
    wire [31:0] imem_read_data;
    wire        imem_read_misaligned;
    wire        imem_read_out_of_range;
    logic        imem_write_enable;
    logic [31:0] imem_write_addr;
    logic [31:0] imem_write_data;
    wire        imem_write_misaligned;
    wire        imem_write_out_of_range;

    logic        dmem_read_enable;
    logic [31:0] dmem_read_addr;
    logic [1:0]  dmem_read_size;
    logic        dmem_read_unsigned;
    wire [31:0] dmem_read_data;
    wire        dmem_read_misaligned;
    wire        dmem_read_out_of_range;
    logic        dmem_write_enable;
    logic [31:0] dmem_write_addr;
    logic [1:0]  dmem_write_size;
    logic [31:0] dmem_write_data;
    wire        dmem_write_misaligned;
    wire        dmem_write_out_of_range;

    integer errors;

    rv32_instruction_memory #(.WORDS(1024)) IMEM (
        .i_clk(clk), .i_rst(rst),
        .i_read_enable(imem_read_enable), .i_read_addr(imem_read_addr),
        .o_read_data(imem_read_data),
        .o_read_misaligned(imem_read_misaligned),
        .o_read_out_of_range(imem_read_out_of_range),
        .i_write_enable(imem_write_enable), .i_write_addr(imem_write_addr),
        .i_write_data(imem_write_data),
        .o_write_misaligned(imem_write_misaligned),
        .o_write_out_of_range(imem_write_out_of_range)
    );

    rv32_data_memory #(.WORDS(1024)) DMEM (
        .i_clk(clk), .i_rst(rst),
        .i_read_enable(dmem_read_enable), .i_read_addr(dmem_read_addr),
        .i_read_size(dmem_read_size), .i_read_unsigned(dmem_read_unsigned),
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

    task automatic imem_write(
        input logic [31:0] address,
        input logic [31:0] data,
        input logic expected_misaligned,
        input logic expected_out_of_range
    );
        begin
            @(negedge clk);
            imem_write_addr   = address;
            imem_write_data   = data;
            imem_write_enable = 1'b1;
            #1;
            if (imem_write_misaligned !== expected_misaligned ||
                imem_write_out_of_range !== expected_out_of_range) begin
                errors = errors + 1;
                $display("ERROR IMEM WRITE fault addr=%08h esperado=%b%b obtenido=%b%b",
                         address, expected_out_of_range, expected_misaligned,
                         imem_write_out_of_range, imem_write_misaligned);
            end
            @(posedge clk); #1;
            imem_write_enable = 1'b0;
        end
    endtask

    task automatic imem_read(
        input logic [31:0] address,
        input logic [31:0] expected_data,
        input logic expected_misaligned,
        input logic expected_out_of_range
    );
        begin
            @(posedge clk);
            imem_read_addr   = address;
            imem_read_enable = 1'b1;
            @(negedge clk); #1;
            imem_read_enable = 1'b0;
            if (imem_read_data !== expected_data ||
                imem_read_misaligned !== expected_misaligned ||
                imem_read_out_of_range !== expected_out_of_range) begin
                errors = errors + 1;
                $display("ERROR IMEM READ addr=%08h data=%08h esperado=%08h fault=%b%b esperado=%b%b",
                         address, imem_read_data, expected_data,
                         imem_read_out_of_range, imem_read_misaligned,
                         expected_out_of_range, expected_misaligned);
            end
        end
    endtask

    task automatic dmem_write(
        input logic [31:0] address,
        input logic [1:0] size,
        input logic [31:0] data,
        input logic expected_misaligned,
        input logic expected_out_of_range
    );
        begin
            @(negedge clk);
            dmem_write_addr   = address;
            dmem_write_size   = size;
            dmem_write_data   = data;
            dmem_write_enable = 1'b1;
            #1;
            if (dmem_write_misaligned !== expected_misaligned ||
                dmem_write_out_of_range !== expected_out_of_range) begin
                errors = errors + 1;
                $display("ERROR DMEM WRITE fault addr=%08h size=%0d esperado=%b%b obtenido=%b%b",
                         address, size, expected_out_of_range, expected_misaligned,
                         dmem_write_out_of_range, dmem_write_misaligned);
            end
            @(posedge clk); #1;
            dmem_write_enable = 1'b0;
        end
    endtask

    task automatic dmem_read(
        input logic [31:0] address,
        input logic [1:0] size,
        input logic unsigned_load,
        input logic [31:0] expected_data,
        input logic expected_misaligned,
        input logic expected_out_of_range
    );
        begin
            @(posedge clk);
            dmem_read_addr     = address;
            dmem_read_size     = size;
            dmem_read_unsigned = unsigned_load;
            dmem_read_enable   = 1'b1;
            @(negedge clk); #1;
            dmem_read_enable = 1'b0;
            if (dmem_read_data !== expected_data ||
                dmem_read_misaligned !== expected_misaligned ||
                dmem_read_out_of_range !== expected_out_of_range) begin
                errors = errors + 1;
                $display("ERROR DMEM READ addr=%08h size=%0d data=%08h esperado=%08h fault=%b%b esperado=%b%b",
                         address, size, dmem_read_data, expected_data,
                         dmem_read_out_of_range, dmem_read_misaligned,
                         expected_out_of_range, expected_misaligned);
            end
        end
    endtask

    initial begin
        errors = 0;
        rst = 1'b1;
        imem_read_enable = 1'b0;
        imem_read_addr = 32'd0;
        imem_write_enable = 1'b0;
        imem_write_addr = 32'd0;
        imem_write_data = 32'd0;
        dmem_read_enable = 1'b0;
        dmem_read_addr = 32'd0;
        dmem_read_size = 2'd2;
        dmem_read_unsigned = 1'b0;
        dmem_write_enable = 1'b0;
        dmem_write_addr = 32'd0;
        dmem_write_size = 2'd2;
        dmem_write_data = 32'd0;

        repeat (3) @(posedge clk);
        rst = 1'b0;

        imem_write(32'd0,    32'h0010_0093, 1'b0, 1'b0);
        imem_write(32'd4,    32'h0020_8113, 1'b0, 1'b0);
        imem_write(32'd4092, 32'h0010_0073, 1'b0, 1'b0);
        imem_read(32'd0,    32'h0010_0093, 1'b0, 1'b0);
        imem_read(32'd4,    32'h0020_8113, 1'b0, 1'b0);
        imem_read(32'd4092, 32'h0010_0073, 1'b0, 1'b0);
        imem_write(32'd2, 32'hDEAD_BEEF, 1'b1, 1'b0);
        imem_write(32'd4096, 32'hDEAD_BEEF, 1'b0, 1'b1);
        imem_read(32'd2, 32'd0, 1'b1, 1'b0);
        imem_read(32'd4096, 32'd0, 1'b0, 1'b1);
        imem_read(32'd0, 32'h0010_0093, 1'b0, 1'b0);

        dmem_write(32'h0000_0100, 2'd2, 32'h1122_3344, 1'b0, 1'b0);
        dmem_read(32'h0000_0100, 2'd2, 1'b0, 32'h1122_3344, 1'b0, 1'b0);
        dmem_write(32'h0000_0101, 2'd0, 32'h0000_00AA, 1'b0, 1'b0);
        dmem_write(32'h0000_0103, 2'd0, 32'h0000_0080, 1'b0, 1'b0);
        dmem_read(32'h0000_0100, 2'd2, 1'b0, 32'h8022_AA44, 1'b0, 1'b0);
        dmem_read(32'h0000_0103, 2'd0, 1'b0, 32'hFFFF_FF80, 1'b0, 1'b0);
        dmem_read(32'h0000_0103, 2'd0, 1'b1, 32'h0000_0080, 1'b0, 1'b0);
        dmem_write(32'h0000_0102, 2'd1, 32'h0000_BEEF, 1'b0, 1'b0);
        dmem_read(32'h0000_0102, 2'd1, 1'b0, 32'hFFFF_BEEF, 1'b0, 1'b0);
        dmem_read(32'h0000_0102, 2'd1, 1'b1, 32'h0000_BEEF, 1'b0, 1'b0);
        dmem_write(32'h0000_0100, 2'd1, 32'h0000_8001, 1'b0, 1'b0);
        dmem_read(32'h0000_0100, 2'd1, 1'b0, 32'hFFFF_8001, 1'b0, 1'b0);
        dmem_read(32'h0000_0100, 2'd2, 1'b0, 32'hBEEF_8001, 1'b0, 1'b0);

        dmem_write(32'd4095, 2'd0, 32'h0000_007F, 1'b0, 1'b0);
        dmem_read(32'd4095, 2'd0, 1'b0, 32'h0000_007F, 1'b0, 1'b0);
        dmem_write(32'h0000_0101, 2'd1, 32'h0000_1234, 1'b1, 1'b0);
        dmem_write(32'd4095, 2'd1, 32'h0000_1234, 1'b1, 1'b1);
        dmem_read(32'h0000_0101, 2'd1, 1'b0, 32'd0, 1'b1, 1'b0);
        dmem_read(32'd4093, 2'd2, 1'b0, 32'd0, 1'b1, 1'b1);
        dmem_read(32'd4096, 2'd0, 1'b0, 32'd0, 1'b0, 1'b1);

        if (errors == 0)
            $display("RESULTADO: MEMORIAS RV32 OK");
        else
            $fatal(1, "RESULTADO: %0d ERRORES", errors);

        $finish;
    end

endmodule
