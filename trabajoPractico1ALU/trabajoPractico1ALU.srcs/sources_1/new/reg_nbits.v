`timescale 1ns / 1ps

module reg_nbits #(
    parameter NB_BITS = 8
)(
    input wire                 i_clk,
    input wire                 i_enable,
    input wire                 i_rst,
    input wire [NB_BITS-1:0]   i_D,

    output reg [NB_BITS-1:0]   o_Q
);

    initial begin
        o_Q = {NB_BITS{1'b0}};
    end

    always @(posedge i_clk) begin
    
        if (i_rst)
            o_Q = {NB_BITS{1'b0}};

        else if (i_enable)
            o_Q <= i_D;

    end

endmodule