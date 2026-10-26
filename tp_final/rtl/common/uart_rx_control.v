`timescale 1ns / 1ps

// Unidad de control del receptor UART.
// Decide la secuencia IDLE -> START -> DATA -> STOP y genera las ordenes
// para el datapath. No contiene contadores ni registros de datos.
module uart_rx_control (
    input  wire i_clk,
    input  wire i_rst,
    input  wire i_tick,

    input  wire i_rx_sync,
    input  wire i_start_middle,
    input  wire i_sample_finished,
    input  wire i_last_data_bit,
    input  wire i_stop_finished,

    output reg  o_clear_sample_count,
    output reg  o_increment_sample_count,
    output reg  o_clear_bit_count,
    output reg  o_increment_bit_count,
    output reg  o_shift_data,
    output reg  o_load_output,
    output reg  o_done,
    output reg  o_frame_error
);

    localparam [1:0] IDLE  = 2'b00;
    localparam [1:0] START = 2'b01;
    localparam [1:0] DATA  = 2'b10;
    localparam [1:0] STOP  = 2'b11;

    reg [1:0] state;
    reg [1:0] next_state;

    wire frame_finished;
    assign frame_finished =
        (state == STOP) && i_tick && i_stop_finished;

    // Registro de estado y pulsos de fin de recepcion.
    always @(posedge i_clk) begin
        if (i_rst) begin
            state         <= IDLE;
            o_done        <= 1'b0;
            o_frame_error <= 1'b0;
        end
        else begin
            state         <= next_state;
            o_done        <= frame_finished;
            o_frame_error <= frame_finished && !i_rx_sync;
        end
    end

    // Logica de proximo estado y senales de control hacia el datapath.
    always @(*) begin
        next_state               = state;
        o_clear_sample_count     = 1'b0;
        o_increment_sample_count = 1'b0;
        o_clear_bit_count        = 1'b0;
        o_increment_bit_count    = 1'b0;
        o_shift_data             = 1'b0;
        o_load_output            = 1'b0;

        case (state)
            IDLE: begin
                o_clear_sample_count = 1'b1;
                if (!i_rx_sync)
                    next_state = START;
            end

            START: begin
                if (i_tick) begin
                    if (i_start_middle) begin
                        o_clear_sample_count = 1'b1;
                        if (!i_rx_sync) begin
                            o_clear_bit_count = 1'b1;
                            next_state = DATA;
                        end
                        else begin
                            next_state = IDLE;
                        end
                    end
                    else begin
                        o_increment_sample_count = 1'b1;
                    end
                end
            end

            DATA: begin
                if (i_tick) begin
                    if (i_sample_finished) begin
                        o_clear_sample_count = 1'b1;
                        o_shift_data = 1'b1;

                        if (i_last_data_bit) begin
                            o_clear_bit_count = 1'b1;
                            next_state = STOP;
                        end
                        else begin
                            o_increment_bit_count = 1'b1;
                        end
                    end
                    else begin
                        o_increment_sample_count = 1'b1;
                    end
                end
            end

            STOP: begin
                if (i_tick) begin
                    if (i_stop_finished) begin
                        o_clear_sample_count = 1'b1;
                        o_load_output = 1'b1;
                        next_state = IDLE;
                    end
                    else begin
                        o_increment_sample_count = 1'b1;
                    end
                end
            end

            default: begin
                o_clear_sample_count = 1'b1;
                o_clear_bit_count = 1'b1;
                next_state = IDLE;
            end
        endcase
    end

endmodule
