`timescale 1ns / 1ps

// Camino de datos del transmisor UART.
// Contiene contadores, shift register y multiplexor de salida TX.
module uart_tx_datapath #(
    parameter integer DATA_BITS  = 8,
    parameter integer STOP_BITS  = 1,
    parameter integer OVERSAMPLE = 16
)(
    input  wire                 i_clk,
    input  wire                 i_rst,
    input  wire                 i_tick,
    input  wire [DATA_BITS-1:0] i_data,

    input  wire                 i_load_data,
    input  wire                 i_clear_sample_count,
    input  wire                 i_increment_sample_count,
    input  wire                 i_clear_bit_count,
    input  wire                 i_increment_bit_count,
    input  wire                 i_shift_data,
    input  wire [1:0]           i_tx_select,

    output wire                 o_sample_finished,
    output wire                 o_stop_finished,
    output wire                 o_last_data_bit,
    output wire                 o_data_bit,
    output reg                  o_tx
);

    localparam [1:0] TX_HIGH = 2'b00;
    localparam [1:0] TX_LOW  = 2'b01;
    localparam [1:0] TX_DATA = 2'b10;

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

    reg [SAMPLE_BITS-1:0] sample_count;
    reg [DATA_COUNT_BITS-1:0] bit_count;
    reg [DATA_BITS-1:0] data_shift;

    assign o_sample_finished = (sample_count == OVERSAMPLE - 1);
    assign o_stop_finished =
        (sample_count == (OVERSAMPLE * STOP_BITS) - 1);
    assign o_last_data_bit = (bit_count == DATA_BITS - 1);
    assign o_data_bit = data_shift[0];

    always @(posedge i_clk) begin
        if (i_rst) begin
            sample_count <= {SAMPLE_BITS{1'b0}};
            bit_count    <= {DATA_COUNT_BITS{1'b0}};
            data_shift   <= {DATA_BITS{1'b0}};
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

            if (i_load_data)
                data_shift <= i_data;
            else if (i_shift_data)
                data_shift <= {1'b0, data_shift[DATA_BITS-1:1]};
        end
    end

    always @(*) begin
        case (i_tx_select)
            TX_LOW:  o_tx = 1'b0;
            TX_DATA: o_tx = data_shift[0];
            TX_HIGH: o_tx = 1'b1;
            default: o_tx = 1'b1;
        endcase
    end

endmodule
