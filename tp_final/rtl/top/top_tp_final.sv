`timescale 1ns / 1ps

// Top incremental actual: validación de IMEM y DMEM por UART.
module top_memory_uart_smoke #(
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

    wire [7:0] rx_data; wire rx_empty; wire rx_read;
    wire [7:0] tx_data; wire tx_write; wire tx_full;

    wire imem_read_enable; wire [31:0] imem_read_addr;
    wire [31:0] imem_read_data; wire imem_read_misaligned;
    wire imem_read_out_of_range; wire imem_write_enable;
    wire [31:0] imem_write_addr; wire [31:0] imem_write_data;
    wire imem_write_misaligned; wire imem_write_out_of_range;

    wire dmem_read_enable; wire [31:0] dmem_read_addr;
    wire [1:0] dmem_read_size; wire dmem_read_unsigned;
    wire [31:0] dmem_read_data; wire dmem_read_misaligned;
    wire dmem_read_out_of_range; wire dmem_write_enable;
    wire [31:0] dmem_write_addr; wire [1:0] dmem_write_size;
    wire [31:0] dmem_write_data; wire dmem_write_misaligned;
    wire dmem_write_out_of_range; wire [31:0] last_read_data;

    assign o_leds = last_read_data[7:0];

    uart #(
        .CLOCK_FREQ_HZ(CLOCK_FREQ_HZ), .BAUD_RATE(BAUD_RATE),
        .DATA_BITS(8), .STOP_BITS(1), .OVERSAMPLE(16)
    ) UART (
        .i_clk(i_clk), .i_rst(i_rst), .i_rx(i_uart_rx), .o_tx(o_uart_tx),
        .o_r_data(rx_data), .i_rd(rx_read), .o_rx_empty(rx_empty),
        .i_w_data(tx_data), .i_wr(tx_write), .o_tx_full(tx_full),
        .o_rx_overrun(o_rx_overrun), .o_frame_error(o_frame_error)
    );

    memory_uart_smoke_controller CONTROLLER (
        .i_clk(i_clk), .i_rst(i_rst),
        .i_r_data(rx_data), .i_rx_empty(rx_empty), .o_rd(rx_read),
        .o_w_data(tx_data), .o_wr(tx_write), .i_tx_full(tx_full),
        .o_imem_read_enable(imem_read_enable), .o_imem_read_addr(imem_read_addr),
        .i_imem_read_data(imem_read_data),
        .i_imem_read_misaligned(imem_read_misaligned),
        .i_imem_read_out_of_range(imem_read_out_of_range),
        .o_imem_write_enable(imem_write_enable), .o_imem_write_addr(imem_write_addr),
        .o_imem_write_data(imem_write_data),
        .i_imem_write_misaligned(imem_write_misaligned),
        .i_imem_write_out_of_range(imem_write_out_of_range),
        .o_dmem_read_enable(dmem_read_enable), .o_dmem_read_addr(dmem_read_addr),
        .o_dmem_read_size(dmem_read_size), .o_dmem_read_unsigned(dmem_read_unsigned),
        .i_dmem_read_data(dmem_read_data),
        .i_dmem_read_misaligned(dmem_read_misaligned),
        .i_dmem_read_out_of_range(dmem_read_out_of_range),
        .o_dmem_write_enable(dmem_write_enable), .o_dmem_write_addr(dmem_write_addr),
        .o_dmem_write_size(dmem_write_size), .o_dmem_write_data(dmem_write_data),
        .i_dmem_write_misaligned(dmem_write_misaligned),
        .i_dmem_write_out_of_range(dmem_write_out_of_range),
        .o_last_read_data(last_read_data)
    );

    rv32_instruction_memory #(.WORDS(1024)) IMEM (
        .i_clk(i_clk), .i_rst(i_rst),
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
        .i_clk(i_clk), .i_rst(i_rst),
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

endmodule
