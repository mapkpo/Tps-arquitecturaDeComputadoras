`timescale 1ns / 1ps

// Top conservado para repetir la validación del banco de registros.
module top_register_file_uart_smoke #(
    parameter integer CLOCK_FREQ_HZ = 100_000_000,
    parameter integer BAUD_RATE     = 115_200
)(
    input  wire       i_clk,
    input  wire       i_rst,
    input  wire       i_uart_rx,
    output wire       o_uart_tx,
    output wire [7:0] o_leds,
    output wire       o_rx_overrun,
    output wire       o_frame_error
);

    wire [7:0]  rx_data;
    wire        rx_empty;
    wire        rx_read;
    wire [7:0]  tx_data;
    wire        tx_write;
    wire        tx_full;
    wire        reg_write_enable;
    wire [4:0]  reg_write_addr;
    wire [31:0] reg_write_data;
    wire [4:0]  reg_read_addr_1;
    wire [4:0]  reg_read_addr_2;
    wire [31:0] reg_read_data_1;
    wire [31:0] reg_read_data_2;
    wire [31:0] last_read_1;

    assign o_leds = last_read_1[7:0];

    uart #(
        .CLOCK_FREQ_HZ(CLOCK_FREQ_HZ), .BAUD_RATE(BAUD_RATE),
        .DATA_BITS(8), .STOP_BITS(1), .OVERSAMPLE(16)
    ) UART (
        .i_clk(i_clk), .i_rst(i_rst), .i_rx(i_uart_rx), .o_tx(o_uart_tx),
        .o_r_data(rx_data), .i_rd(rx_read), .o_rx_empty(rx_empty),
        .i_w_data(tx_data), .i_wr(tx_write), .o_tx_full(tx_full),
        .o_rx_overrun(o_rx_overrun), .o_frame_error(o_frame_error)
    );

    register_file_uart_smoke_controller CONTROLLER (
        .i_clk(i_clk), .i_rst(i_rst),
        .i_r_data(rx_data), .i_rx_empty(rx_empty), .o_rd(rx_read),
        .o_w_data(tx_data), .o_wr(tx_write), .i_tx_full(tx_full),
        .o_reg_write_enable(reg_write_enable),
        .o_reg_write_addr(reg_write_addr), .o_reg_write_data(reg_write_data),
        .o_reg_read_addr_1(reg_read_addr_1), .o_reg_read_addr_2(reg_read_addr_2),
        .i_reg_read_data_1(reg_read_data_1), .i_reg_read_data_2(reg_read_data_2),
        .o_last_read_1(last_read_1)
    );

    rv32_register_file REGISTER_FILE (
        .i_clk(i_clk), .i_rst(i_rst),
        .i_write_enable(reg_write_enable),
        .i_write_addr(reg_write_addr), .i_write_data(reg_write_data),
        .i_read_addr_1(reg_read_addr_1), .i_read_addr_2(reg_read_addr_2),
        .o_read_data_1(reg_read_data_1), .o_read_data_2(reg_read_data_2),
        .i_debug_read_addr(5'd0), .o_debug_read_data()
    );

endmodule
