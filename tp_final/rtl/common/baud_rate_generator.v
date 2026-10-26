`timescale 1ns / 1ps

module baud_rate_generator #(
    parameter integer CLOCK_FREQ_HZ = 100_000_000,
    parameter integer BAUD_RATE     = 19_200,
    parameter integer OVERSAMPLE    = 16
)(
    input  wire i_clk,
    input  wire i_rst,
    output reg  o_tick
);

    localparam integer TICK_FREQ_HZ = BAUD_RATE * OVERSAMPLE;
    localparam integer DIVISOR =
        (CLOCK_FREQ_HZ + (TICK_FREQ_HZ / 2)) / TICK_FREQ_HZ;

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

    localparam integer COUNTER_BITS = (DIVISOR <= 1) ? 1 : clog2(DIVISOR);

    reg [COUNTER_BITS-1:0] counter;

    always @(posedge i_clk) begin
        if (i_rst) begin
            counter <= {COUNTER_BITS{1'b0}};
            o_tick  <= 1'b0;
        end
        else if (counter == DIVISOR - 1) begin
            counter <= {COUNTER_BITS{1'b0}};
            o_tick  <= 1'b1;
        end
        else begin
            counter <= counter + 1'b1;
            o_tick  <= 1'b0;
        end
    end

endmodule
