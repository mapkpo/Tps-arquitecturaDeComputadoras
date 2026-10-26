`timescale 1ns / 1ps

// Wrapper del receptor UART. La unidad de control contiene solamente la FSM;
// el datapath contiene sincronizadores, contadores y registros de datos.
module uart_rx #(
    parameter integer DATA_BITS  = 8,
    parameter integer STOP_BITS  = 1,
    parameter integer OVERSAMPLE = 16
)(
    input  wire                 i_clk,
    input  wire                 i_rst,
    input  wire                 i_tick,
    input  wire                 i_rx,

    output wire [DATA_BITS-1:0] o_data,
    output wire                 o_done,
    output wire                 o_frame_error
);

    wire rx_sync;
    wire start_middle;
    wire sample_finished;
    wire last_data_bit;
    wire stop_finished;

    wire clear_sample_count;
    wire increment_sample_count;
    wire clear_bit_count;
    wire increment_bit_count;
    wire shift_data;
    wire load_output;

    uart_rx_control CONTROL (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_tick(i_tick),
        .i_rx_sync(rx_sync),
        .i_start_middle(start_middle),
        .i_sample_finished(sample_finished),
        .i_last_data_bit(last_data_bit),
        .i_stop_finished(stop_finished),
        .o_clear_sample_count(clear_sample_count),
        .o_increment_sample_count(increment_sample_count),
        .o_clear_bit_count(clear_bit_count),
        .o_increment_bit_count(increment_bit_count),
        .o_shift_data(shift_data),
        .o_load_output(load_output),
        .o_done(o_done),
        .o_frame_error(o_frame_error)
    );

    uart_rx_datapath #(
        .DATA_BITS(DATA_BITS),
        .STOP_BITS(STOP_BITS),
        .OVERSAMPLE(OVERSAMPLE)
    ) DATAPATH (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_tick(i_tick),
        .i_rx(i_rx),
        .i_clear_sample_count(clear_sample_count),
        .i_increment_sample_count(increment_sample_count),
        .i_clear_bit_count(clear_bit_count),
        .i_increment_bit_count(increment_bit_count),
        .i_shift_data(shift_data),
        .i_load_output(load_output),
        .o_rx_sync(rx_sync),
        .o_start_middle(start_middle),
        .o_sample_finished(sample_finished),
        .o_last_data_bit(last_data_bit),
        .o_stop_finished(stop_finished),
        .o_data(o_data)
    );

endmodule
