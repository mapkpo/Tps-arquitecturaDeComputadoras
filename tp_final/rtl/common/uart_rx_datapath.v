`timescale 1ns / 1ps

// Camino de datos del receptor UART.
// Contiene el sincronizador de RX, los contadores, el shift register y el
// registro de salida. Ejecuta las ordenes generadas por uart_rx_control.
module uart_rx_datapath #(
    parameter integer DATA_BITS  = 8,
    parameter integer STOP_BITS  = 1,
    parameter integer OVERSAMPLE = 16
)(
    input  wire                 i_clk,
    input  wire                 i_rst,
    input  wire                 i_tick,
    input  wire                 i_rx,

    input  wire                 i_clear_sample_count,
    input  wire                 i_increment_sample_count,
    input  wire                 i_clear_bit_count,
    input  wire                 i_increment_bit_count,
    input  wire                 i_shift_data,
    input  wire                 i_load_output,

    output wire                 o_rx_sync,
    output wire                 o_start_middle,
    output wire                 o_sample_finished,
    output wire                 o_last_data_bit,
    output wire                 o_stop_finished,
    output reg  [DATA_BITS-1:0] o_data
);

    function integer clog2;
        input integer value;
        integer i;
        begin
            value = value - 1;
            for (i = 0; value > 0; i = i + 1)
                value = value >> 1;
            clog2 = i;
        end
    endfunction

    localparam integer SAMPLE_BITS =
        (OVERSAMPLE * STOP_BITS <= 1) ? 1 : clog2(OVERSAMPLE * STOP_BITS);
    localparam integer DATA_COUNT_BITS =
        (DATA_BITS <= 1) ? 1 : clog2(DATA_BITS);

    reg rx_meta;
    reg rx_sync;
    reg [SAMPLE_BITS-1:0] sample_count;
    reg [DATA_COUNT_BITS-1:0] bit_count;
    reg [DATA_BITS-1:0] data_shift;

    assign o_rx_sync         = rx_sync;
    assign o_start_middle    = (sample_count == (OVERSAMPLE / 2) - 1);
    assign o_sample_finished = (sample_count == OVERSAMPLE - 1);
    assign o_last_data_bit   = (bit_count == DATA_BITS - 1);
    assign o_stop_finished   =
        (sample_count == (OVERSAMPLE * STOP_BITS) - 1);

    // Sincronizador de dos flip-flops para la entrada asincrona.
    always @(posedge i_clk) begin
        if (i_rst) begin
            rx_meta <= 1'b1;
            rx_sync <= 1'b1;
        end
        else begin
            rx_meta <= i_rx;
            rx_sync <= rx_meta;
        end
    end

    always @(posedge i_clk) begin
        if (i_rst) begin
            sample_count <= {SAMPLE_BITS{1'b0}};
            bit_count    <= {DATA_COUNT_BITS{1'b0}};
            data_shift   <= {DATA_BITS{1'b0}};
            o_data       <= {DATA_BITS{1'b0}};
        end
        else begin
            if (i_clear_sample_count)
                sample_count <= {SAMPLE_BITS{1'b0}};
            else if (i_tick && i_increment_sample_count)
                sample_count <= sample_count + 1'b1;

            if (i_clear_bit_count)
                bit_count <= {DATA_COUNT_BITS{1'b0}};
            else if (i_increment_bit_count)
                bit_count <= bit_count + 1'b1;

            if (i_shift_data)
                data_shift <= {rx_sync, data_shift[DATA_BITS-1:1]};

            if (i_load_output)
                o_data <= data_shift;
        end
    end

endmodule
