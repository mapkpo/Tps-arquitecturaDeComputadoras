`timescale 1ns / 1ps

// Protocolo temporal para validar la ALU RV32 en placa.
// Request:  A[31:0] little-endian, B[31:0] little-endian, OP[3:0].
// Response: RESULT[31:0] little-endian.
module alu_uart_smoke_controller (
    input  logic        i_clk,
    input  logic        i_rst,

    input  logic [7:0]  i_r_data,
    input  logic        i_rx_empty,
    output logic        o_rd,

    output logic [7:0]  o_w_data,
    output logic        o_wr,
    input  logic        i_tx_full,

    output logic [31:0] o_alu_a,
    output logic [31:0] o_alu_b,
    output logic [3:0]  o_alu_op,
    input  logic [31:0] i_alu_result,

    output logic [31:0] o_last_result
);

    typedef enum logic [2:0] {
        RX_BYTE,
        RX_WAIT_EMPTY,
        EXECUTE,
        TX_SEND,
        TX_WAIT_FULL,
        TX_WAIT_EMPTY
    } state_t;

    state_t     state;
    logic [3:0] rx_index;
    logic [1:0] tx_index;

    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            state         <= RX_BYTE;
            rx_index      <= 4'd0;
            tx_index      <= 2'd0;
            o_rd          <= 1'b0;
            o_wr          <= 1'b0;
            o_w_data      <= 8'h00;
            o_alu_a       <= 32'h0000_0000;
            o_alu_b       <= 32'h0000_0000;
            o_alu_op      <= 4'h0;
            o_last_result <= 32'h0000_0000;
        end
        else begin
            o_rd <= 1'b0;
            o_wr <= 1'b0;

            case (state)
                RX_BYTE: begin
                    if (!i_rx_empty) begin
                        case (rx_index)
                            4'd0: o_alu_a[7:0]   <= i_r_data;
                            4'd1: o_alu_a[15:8]  <= i_r_data;
                            4'd2: o_alu_a[23:16] <= i_r_data;
                            4'd3: o_alu_a[31:24] <= i_r_data;
                            4'd4: o_alu_b[7:0]   <= i_r_data;
                            4'd5: o_alu_b[15:8]  <= i_r_data;
                            4'd6: o_alu_b[23:16] <= i_r_data;
                            4'd7: o_alu_b[31:24] <= i_r_data;
                            4'd8: o_alu_op       <= i_r_data[3:0];
                            default: begin
                                o_alu_a  <= 32'h0000_0000;
                                o_alu_b  <= 32'h0000_0000;
                                o_alu_op <= 4'h0;
                            end
                        endcase
                        o_rd  <= 1'b1;
                        state <= RX_WAIT_EMPTY;
                    end
                end

                RX_WAIT_EMPTY: begin
                    if (i_rx_empty) begin
                        if (rx_index == 4'd8) begin
                            state <= EXECUTE;
                        end
                        else begin
                            rx_index <= rx_index + 1'b1;
                            state    <= RX_BYTE;
                        end
                    end
                end

                EXECUTE: begin
                    o_last_result <= i_alu_result;
                    tx_index      <= 2'd0;
                    state         <= TX_SEND;
                end

                TX_SEND: begin
                    if (!i_tx_full) begin
                        case (tx_index)
                            2'd0: o_w_data <= o_last_result[7:0];
                            2'd1: o_w_data <= o_last_result[15:8];
                            2'd2: o_w_data <= o_last_result[23:16];
                            2'd3: o_w_data <= o_last_result[31:24];
                        endcase
                        o_wr  <= 1'b1;
                        state <= TX_WAIT_FULL;
                    end
                end

                TX_WAIT_FULL: begin
                    if (i_tx_full)
                        state <= TX_WAIT_EMPTY;
                end

                TX_WAIT_EMPTY: begin
                    if (!i_tx_full) begin
                        if (tx_index == 2'd3) begin
                            rx_index <= 4'd0;
                            state    <= RX_BYTE;
                        end
                        else begin
                            tx_index <= tx_index + 1'b1;
                            state    <= TX_SEND;
                        end
                    end
                end

                default: begin
                    state    <= RX_BYTE;
                    rx_index <= 4'd0;
                end
            endcase
        end
    end

endmodule
