`timescale 1ns / 1ps

// Top conservado para repetir la validación de decoder e inmediatos.
module top_decoder_uart_smoke #(
    parameter integer CLOCK_FREQ_HZ = 100_000_000,
    parameter integer BAUD_RATE     = 115_200
)(
    input wire i_clk, input wire i_rst, input wire i_uart_rx,
    output wire o_uart_tx, output wire [7:0] o_leds,
    output wire o_rx_overrun, output wire o_frame_error
);
    wire [7:0] rx_data; wire rx_empty; wire rx_read;
    wire [7:0] tx_data; wire tx_write; wire tx_full;
    wire [31:0] instruction; wire [4:0] rs1, rs2, rd;
    wire legal, halt, uses_rs1, uses_rs2, reg_write, alu_src_imm;
    wire [3:0] alu_op; wire [2:0] imm_type;
    wire mem_read, mem_write; wire [1:0] mem_size;
    wire mem_unsigned; wire [1:0] branch, jump, wb_sel;
    wire [31:0] immediate;

    assign o_leds = instruction[7:0];

    uart #(
        .CLOCK_FREQ_HZ(CLOCK_FREQ_HZ), .BAUD_RATE(BAUD_RATE),
        .DATA_BITS(8), .STOP_BITS(1), .OVERSAMPLE(16)
    ) UART (
        .i_clk(i_clk), .i_rst(i_rst), .i_rx(i_uart_rx), .o_tx(o_uart_tx),
        .o_r_data(rx_data), .i_rd(rx_read), .o_rx_empty(rx_empty),
        .i_w_data(tx_data), .i_wr(tx_write), .o_tx_full(tx_full),
        .o_rx_overrun(o_rx_overrun), .o_frame_error(o_frame_error)
    );

    decoder_uart_smoke_controller CONTROLLER (
        .i_clk(i_clk), .i_rst(i_rst),
        .i_r_data(rx_data), .i_rx_empty(rx_empty), .o_rd(rx_read),
        .o_w_data(tx_data), .o_wr(tx_write), .i_tx_full(tx_full),
        .o_instruction(instruction),
        .i_rs1(rs1), .i_rs2(rs2), .i_rd(rd),
        .i_legal(legal), .i_halt(halt),
        .i_uses_rs1(uses_rs1), .i_uses_rs2(uses_rs2),
        .i_reg_write(reg_write), .i_alu_src_imm(alu_src_imm),
        .i_alu_op(alu_op), .i_imm_type(imm_type),
        .i_mem_read(mem_read), .i_mem_write(mem_write),
        .i_mem_size(mem_size), .i_mem_unsigned(mem_unsigned),
        .i_branch(branch), .i_jump(jump), .i_wb_sel(wb_sel),
        .i_immediate(immediate)
    );

    rv32_decoder DECODER (
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

    rv32_immediate_generator IMMEDIATE_GENERATOR (
        .i_instruction(instruction), .i_imm_type(imm_type),
        .o_immediate(immediate)
    );
endmodule
