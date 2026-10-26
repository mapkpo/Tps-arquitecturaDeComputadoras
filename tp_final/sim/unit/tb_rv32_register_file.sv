`timescale 1ns / 1ps

module tb_rv32_register_file;

    logic        clk;
    logic        rst;
    logic        write_enable;
    logic [4:0]  write_addr;
    logic [31:0] write_data;
    logic [4:0]  read_addr_1;
    logic [4:0]  read_addr_2;
    logic [31:0] read_data_1;
    logic [31:0] read_data_2;
    integer      errors;

    rv32_register_file DUT (
        .i_clk(clk), .i_rst(rst),
        .i_write_enable(write_enable),
        .i_write_addr(write_addr), .i_write_data(write_data),
        .i_read_addr_1(read_addr_1), .i_read_addr_2(read_addr_2),
        .o_read_data_1(read_data_1), .o_read_data_2(read_data_2),
        .i_debug_read_addr(5'd0), .o_debug_read_data()
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic write_register(input logic [4:0] addr, input logic [31:0] data);
        begin
            @(negedge clk);
            write_addr   = addr;
            write_data   = data;
            write_enable = 1'b1;
            @(posedge clk);
            #1 write_enable = 1'b0;
        end
    endtask

    task automatic check_pair(
        input logic [4:0] addr_1,
        input logic [31:0] expected_1,
        input logic [4:0] addr_2,
        input logic [31:0] expected_2
    );
        begin
            read_addr_1 = addr_1;
            read_addr_2 = addr_2;
            @(negedge clk);
            #1;
            if (read_data_1 !== expected_1) begin
                errors = errors + 1;
                $display("ERROR rs1=x%0d esperado=%h obtenido=%h",
                         addr_1, expected_1, read_data_1);
            end
            if (read_data_2 !== expected_2) begin
                errors = errors + 1;
                $display("ERROR rs2=x%0d esperado=%h obtenido=%h",
                         addr_2, expected_2, read_data_2);
            end
        end
    endtask

    initial begin
        rst = 1'b1;
        write_enable = 1'b0;
        write_addr = 5'd0;
        write_data = 32'h0;
        read_addr_1 = 5'd0;
        read_addr_2 = 5'd0;
        errors = 0;

        repeat (2) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;

        check_pair(5'd0, 32'h0, 5'd31, 32'h0);
        write_register(5'd1, 32'h1234_5678);
        write_register(5'd31, 32'hDEAD_BEEF);
        check_pair(5'd1, 32'h1234_5678, 5'd31, 32'hDEAD_BEEF);

        write_register(5'd0, 32'hFFFF_FFFF);
        check_pair(5'd0, 32'h0, 5'd1, 32'h1234_5678);

        write_register(5'd1, 32'hA5A5_5A5A);
        check_pair(5'd1, 32'hA5A5_5A5A, 5'd1, 32'hA5A5_5A5A);

        if (errors == 0)
            $display("RESULTADO: BANCO DE REGISTROS RV32 OK");
        else
            $fatal(1, "RESULTADO: %0d ERRORES", errors);

        $finish;
    end

endmodule
