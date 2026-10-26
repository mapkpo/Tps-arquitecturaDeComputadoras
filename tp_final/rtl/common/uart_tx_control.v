`timescale 1ns / 1ps

// Unidad de control del transmisor UART.
// Contiene la FSM IDLE -> START -> DATA -> STOP.
module uart_tx_control (
    input  wire       i_clk,
    input  wire       i_rst,
    input  wire       i_tick,
    input  wire       i_start,

    input  wire       i_sample_finished,
    input  wire       i_stop_finished,
    input  wire       i_last_data_bit,

    output reg        o_load_data,
    output reg        o_clear_sample_count,
    output reg        o_increment_sample_count,
    output reg        o_clear_bit_count,
    output reg        o_increment_bit_count,
    output reg        o_shift_data,
    output reg  [1:0] o_tx_select,
    output wire       o_busy,
    output reg        o_done
);

    localparam [1:0] IDLE  = 2'b00;
    localparam [1:0] START = 2'b01;
    localparam [1:0] DATA  = 2'b10;
    localparam [1:0] STOP  = 2'b11;

    localparam [1:0] TX_HIGH = 2'b00;
    localparam [1:0] TX_LOW  = 2'b01;
    localparam [1:0] TX_DATA = 2'b10;

    reg [1:0] state;
    reg [1:0] next_state;

    wire frame_finished;
    assign frame_finished =
        (state == STOP) && i_tick && i_stop_finished;
    assign o_busy = (state != IDLE);

    always @(posedge i_clk) begin
        if (i_rst) begin
            state  <= IDLE;
            o_done <= 1'b0;
        end
        else begin
            state  <= next_state;
            o_done <= frame_finished;
        end
    end

    always @(*) begin
        next_state               = state;
        o_load_data              = 1'b0;
        o_clear_sample_count     = 1'b0;
        o_increment_sample_count = 1'b0;
        o_clear_bit_count        = 1'b0;
        o_increment_bit_count    = 1'b0;
        o_shift_data             = 1'b0;
        o_tx_select              = TX_HIGH;

        case (state)
            IDLE: begin
                o_tx_select = TX_HIGH;
                o_clear_sample_count = 1'b1;

                if (i_start) begin
                    o_load_data = 1'b1;
                    o_clear_bit_count = 1'b1;
                    next_state = START;
                end
            end

            START: begin
                o_tx_select = TX_LOW;
                if (i_tick) begin
                    if (i_sample_finished) begin
                        o_clear_sample_count = 1'b1;
                        next_state = DATA;
                    end
                    else begin
                        o_increment_sample_count = 1'b1;
                    end
                end
            end

            DATA: begin
                o_tx_select = TX_DATA;
                if (i_tick) begin
                    if (i_sample_finished) begin
                        o_clear_sample_count = 1'b1;

                        if (i_last_data_bit) begin
                            o_clear_bit_count = 1'b1;
                            next_state = STOP;
                        end
                        else begin
                            o_shift_data = 1'b1;
                            o_increment_bit_count = 1'b1;
                        end
                    end
                    else begin
                        o_increment_sample_count = 1'b1;
                    end
                end
            end

            STOP: begin
                o_tx_select = TX_HIGH;
                if (i_tick) begin
                    if (i_stop_finished) begin
                        o_clear_sample_count = 1'b1;
                        next_state = IDLE;
                    end
                    else begin
                        o_increment_sample_count = 1'b1;
                    end
                end
            end

            default: begin
                o_tx_select = TX_HIGH;
                o_clear_sample_count = 1'b1;
                o_clear_bit_count = 1'b1;
                next_state = IDLE;
            end
        endcase
    end

endmodule
