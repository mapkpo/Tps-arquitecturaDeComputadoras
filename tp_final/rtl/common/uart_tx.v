`timescale 1ns / 1ps

// Wrapper del transmisor UART. La FSM y el camino de datos se encuentran en
// modulos separados para facilitar la verificacion y el debugging.
module uart_tx #(
    parameter integer DATA_BITS  = 8,
    parameter integer STOP_BITS  = 1,
    parameter integer OVERSAMPLE = 16
)(
    input  wire                 i_clk,
    input  wire                 i_rst,
    input  wire                 i_tick,
    input  wire [DATA_BITS-1:0] i_data,
    input  wire                 i_start,

    output wire                 o_tx,
    output wire                 o_busy,
    output wire                 o_done
);

    wire sample_finished;
    wire stop_finished;
    wire last_data_bit;
    wire data_bit;

    wire load_data;
    wire clear_sample_count;
    wire increment_sample_count;
    wire clear_bit_count;
    wire increment_bit_count;
    wire shift_data;
    wire [1:0] tx_select;

    uart_tx_control CONTROL (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_tick(i_tick),
        .i_start(i_start),
        .i_sample_finished(sample_finished),
        .i_stop_finished(stop_finished),
        .i_last_data_bit(last_data_bit),
        .o_load_data(load_data),
        .o_clear_sample_count(clear_sample_count),
        .o_increment_sample_count(increment_sample_count),
        .o_clear_bit_count(clear_bit_count),
        .o_increment_bit_count(increment_bit_count),
        .o_shift_data(shift_data),
        .o_tx_select(tx_select),
        .o_busy(o_busy),
        .o_done(o_done)
    );

    uart_tx_datapath #(
        .DATA_BITS(DATA_BITS),
        .STOP_BITS(STOP_BITS),
        .OVERSAMPLE(OVERSAMPLE)
    ) DATAPATH (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_tick(i_tick),
        .i_data(i_data),
        .i_load_data(load_data),
        .i_clear_sample_count(clear_sample_count),
        .i_increment_sample_count(increment_sample_count),
        .i_clear_bit_count(clear_bit_count),
        .i_increment_bit_count(increment_bit_count),
        .i_shift_data(shift_data),
        .i_tx_select(tx_select),
        .o_sample_finished(sample_finished),
        .o_stop_finished(stop_finished),
        .o_last_data_bit(last_data_bit),
        .o_data_bit(data_bit),
        .o_tx(o_tx)
    );

endmodule
