`timescale 1ns / 1ps

module uart #(
    parameter integer CLOCK_FREQ_HZ = 100_000_000,
    parameter integer BAUD_RATE     = 19_200,
    parameter integer DATA_BITS     = 8,
    parameter integer STOP_BITS     = 1,
    parameter integer OVERSAMPLE    = 16
)(
    input  wire                 i_clk,
    input  wire                 i_rst,

    input  wire                 i_rx,
    output wire                 o_tx,

    output wire [DATA_BITS-1:0] o_r_data,
    input  wire                 i_rd,
    output wire                 o_rx_empty,

    input  wire [DATA_BITS-1:0] i_w_data,
    input  wire                 i_wr,
    output wire                 o_tx_full,

    output reg                  o_rx_overrun,
    output wire                 o_frame_error
);

    wire tick;

    wire [DATA_BITS-1:0] rx_data;
    wire rx_done;

    reg [DATA_BITS-1:0] rx_buffer;
    reg rx_empty;

    reg [DATA_BITS-1:0] tx_buffer;
    reg tx_buffer_full;
    reg [DATA_BITS-1:0] tx_data;
    reg tx_start;

    wire tx_busy;
    wire tx_done;

    assign o_r_data   = rx_buffer;
    assign o_rx_empty = rx_empty;
    assign o_tx_full  = tx_buffer_full;

    baud_rate_generator #(
        .CLOCK_FREQ_HZ(CLOCK_FREQ_HZ),
        .BAUD_RATE(BAUD_RATE),
        .OVERSAMPLE(OVERSAMPLE)
    ) BAUD_GEN (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .o_tick(tick)
    );

    uart_rx #(
        .DATA_BITS(DATA_BITS),
        .STOP_BITS(STOP_BITS),
        .OVERSAMPLE(OVERSAMPLE)
    ) RX (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_tick(tick),
        .i_rx(i_rx),
        .o_data(rx_data),
        .o_done(rx_done),
        .o_frame_error(o_frame_error)
    );

    uart_tx #(
        .DATA_BITS(DATA_BITS),
        .STOP_BITS(STOP_BITS),
        .OVERSAMPLE(OVERSAMPLE)
    ) TX (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_tick(tick),
        .i_data(tx_data),
        .i_start(tx_start),
        .o_tx(o_tx),
        .o_busy(tx_busy),
        .o_done(tx_done)
    );

    // Buffer de recepcion de un byte.
    always @(posedge i_clk) begin
        if (i_rst) begin
            rx_buffer    <= {DATA_BITS{1'b0}};
            rx_empty     <= 1'b1;
            o_rx_overrun <= 1'b0;
        end
        else begin
            o_rx_overrun <= 1'b0;

            if (rx_done) begin
                if (!rx_empty)
                    o_rx_overrun <= 1'b1;
                rx_buffer <= rx_data;
                rx_empty  <= 1'b0;
            end
            else if (i_rd && !rx_empty) begin
                rx_empty <= 1'b1;
            end
        end
    end

    // Buffer de transmision de un byte. Permite dejar un byte en espera
    // mientras el transmisor envia el anterior.
    always @(posedge i_clk) begin
        if (i_rst) begin
            tx_buffer      <= {DATA_BITS{1'b0}};
            tx_buffer_full <= 1'b0;
            tx_data        <= {DATA_BITS{1'b0}};
            tx_start       <= 1'b0;
        end
        else begin
            tx_start <= 1'b0;

            if (tx_buffer_full && !tx_busy) begin
                tx_data        <= tx_buffer;
                tx_start       <= 1'b1;
                tx_buffer_full <= 1'b0;
            end

            if (i_wr && !tx_buffer_full) begin
                tx_buffer      <= i_w_data;
                tx_buffer_full <= 1'b1;
            end
        end
    end

endmodule
