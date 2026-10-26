`timescale 1ns / 1ps

module rv32_register_file (
    input  logic        i_clk,
    input  logic        i_rst,

    input  logic        i_write_enable,
    input  logic [4:0]  i_write_addr,
    input  logic [31:0] i_write_data,

    input  logic [4:0]  i_read_addr_1,
    input  logic [4:0]  i_read_addr_2,
    output logic [31:0] o_read_data_1,
    output logic [31:0] o_read_data_2,

    input  logic [4:0]  i_debug_read_addr,
    output logic [31:0] o_debug_read_data
);

    logic [31:0] registers [0:31];
    integer index;

    // Escritura de WB y limpieza arquitectónica en flanco positivo.
    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            for (index = 0; index < 32; index = index + 1)
                registers[index] <= 32'h0000_0000;
        end
        else if (i_write_enable && (i_write_addr != 5'd0)) begin
            registers[i_write_addr] <= i_write_data;
        end
    end

    // Lectura de ID en el flanco opuesto, según la indicación del profesor.
    always_ff @(negedge i_clk) begin
        if (i_rst) begin
            o_read_data_1 <= 32'h0000_0000;
            o_read_data_2 <= 32'h0000_0000;
        end
        else begin
            o_read_data_1 <= (i_read_addr_1 == 5'd0)
                ? 32'h0000_0000 : registers[i_read_addr_1];
            o_read_data_2 <= (i_read_addr_2 == 5'd0)
                ? 32'h0000_0000 : registers[i_read_addr_2];
        end
    end

    // Puerto de observación para la Debug Unit. Se usa con el core detenido.
    always_comb begin
        o_debug_read_data = (i_debug_read_addr == 5'd0)
            ? 32'h0000_0000 : registers[i_debug_read_addr];
    end

endmodule
