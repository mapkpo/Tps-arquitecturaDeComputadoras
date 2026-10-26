`timescale 1ns / 1ps

module rv32_instruction_memory #(
    parameter integer WORDS = 1024
)(
    input  logic        i_clk,
    input  logic        i_rst,

    input  logic        i_read_enable,
    input  logic [31:0] i_read_addr,
    output logic [31:0] o_read_data,
    output logic        o_read_misaligned,
    output logic        o_read_out_of_range,

    input  logic        i_write_enable,
    input  logic [31:0] i_write_addr,
    input  logic [31:0] i_write_data,
    output logic        o_write_misaligned,
    output logic        o_write_out_of_range
);

    localparam integer MEMORY_BYTES = WORDS * 4;
    localparam integer ADDR_WIDTH   = $clog2(WORDS);

    (* ram_style = "block" *) logic [31:0] memory [0:WORDS-1];

    always_comb begin
        o_write_misaligned  = |i_write_addr[1:0];
        o_write_out_of_range = (i_write_addr > (MEMORY_BYTES - 4));
    end

    // Puerto de programación: palabras completas en flanco positivo.
    always_ff @(posedge i_clk) begin
        if (i_write_enable && !o_write_misaligned && !o_write_out_of_range)
            memory[i_write_addr[ADDR_WIDTH+1:2]] <= i_write_data;
    end

    // Puerto de fetch: lectura registrada en el flanco opuesto.
    always_ff @(negedge i_clk) begin
        if (i_rst) begin
            o_read_data         <= 32'h0000_0000;
            o_read_misaligned   <= 1'b0;
            o_read_out_of_range <= 1'b0;
        end
        else begin
            o_read_misaligned   <= 1'b0;
            o_read_out_of_range <= 1'b0;
            if (i_read_enable) begin
                o_read_misaligned   <= |i_read_addr[1:0];
                o_read_out_of_range <= (i_read_addr > (MEMORY_BYTES - 4));
                if ((i_read_addr[1:0] == 2'b00) &&
                    (i_read_addr <= (MEMORY_BYTES - 4)))
                    o_read_data <= memory[i_read_addr[ADDR_WIDTH+1:2]];
                else
                    o_read_data <= 32'h0000_0000;
            end
        end
    end

endmodule
