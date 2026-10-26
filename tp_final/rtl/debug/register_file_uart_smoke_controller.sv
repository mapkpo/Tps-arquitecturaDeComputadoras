`timescale 1ns / 1ps

// Protocolo temporal para validar el banco de registros en placa.
// WRITE 0x01: [cmd, rd, data0, data1, data2, data3] -> [0xA1]
// READ2 0x02: [cmd, rs1, rs2]                    -> [rs1 data, rs2 data]
// Los valores de 32 bits se transmiten little-endian.
module register_file_uart_smoke_controller (
    input  logic        i_clk,
    input  logic        i_rst,

    input  logic [7:0]  i_r_data,
    input  logic        i_rx_empty,
    output logic        o_rd,

    output logic [7:0]  o_w_data,
    output logic        o_wr,
    input  logic        i_tx_full,

    output logic        o_reg_write_enable,
    output logic [4:0]  o_reg_write_addr,
    output logic [31:0] o_reg_write_data,
    output logic [4:0]  o_reg_read_addr_1,
    output logic [4:0]  o_reg_read_addr_2,
    input  logic [31:0] i_reg_read_data_1,
    input  logic [31:0] i_reg_read_data_2,

    output logic [31:0] o_last_read_1
);

    localparam logic [7:0] CMD_WRITE = 8'h01;
    localparam logic [7:0] CMD_READ2 = 8'h02;

    typedef enum logic [3:0] {
        RX_BYTE,
        RX_WAIT_EMPTY,
        WRITE_PULSE,
        WRITE_COMMIT,
        READ_CAPTURE,
        PREPARE_ERROR,
        TX_SEND,
        TX_WAIT_FULL,
        TX_WAIT_EMPTY
    } state_t;

    state_t     state;
    logic [7:0] command;
    logic [2:0] rx_index;
    logic [2:0] expected_last_index;
    logic [3:0] tx_index;
    logic [3:0] tx_length;
    logic [7:0] tx_bytes [0:7];

    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            state               <= RX_BYTE;
            command             <= 8'h00;
            rx_index            <= 3'd0;
            expected_last_index <= 3'd0;
            tx_index            <= 4'd0;
            tx_length           <= 4'd0;
            o_rd                <= 1'b0;
            o_wr                <= 1'b0;
            o_w_data            <= 8'h00;
            o_reg_write_enable  <= 1'b0;
            o_reg_write_addr    <= 5'd0;
            o_reg_write_data    <= 32'h0000_0000;
            o_reg_read_addr_1   <= 5'd0;
            o_reg_read_addr_2   <= 5'd0;
            o_last_read_1       <= 32'h0000_0000;
        end
        else begin
            o_rd               <= 1'b0;
            o_wr               <= 1'b0;
            o_reg_write_enable <= 1'b0;

            case (state)
                RX_BYTE: begin
                    if (!i_rx_empty) begin
                        if (rx_index == 3'd0) begin
                            command <= i_r_data;
                            case (i_r_data)
                                CMD_WRITE: expected_last_index <= 3'd5;
                                CMD_READ2: expected_last_index <= 3'd2;
                                default:   expected_last_index <= 3'd0;
                            endcase
                        end
                        else if (command == CMD_WRITE) begin
                            case (rx_index)
                                3'd1: o_reg_write_addr       <= i_r_data[4:0];
                                3'd2: o_reg_write_data[7:0]  <= i_r_data;
                                3'd3: o_reg_write_data[15:8] <= i_r_data;
                                3'd4: o_reg_write_data[23:16] <= i_r_data;
                                3'd5: o_reg_write_data[31:24] <= i_r_data;
                                default: ;
                            endcase
                        end
                        else if (command == CMD_READ2) begin
                            case (rx_index)
                                3'd1: o_reg_read_addr_1 <= i_r_data[4:0];
                                3'd2: o_reg_read_addr_2 <= i_r_data[4:0];
                                default: ;
                            endcase
                        end

                        o_rd  <= 1'b1;
                        state <= RX_WAIT_EMPTY;
                    end
                end

                RX_WAIT_EMPTY: begin
                    if (i_rx_empty) begin
                        if (rx_index == expected_last_index) begin
                            case (command)
                                CMD_WRITE: state <= WRITE_PULSE;
                                CMD_READ2: state <= READ_CAPTURE;
                                default:   state <= PREPARE_ERROR;
                            endcase
                        end
                        else begin
                            rx_index <= rx_index + 1'b1;
                            state    <= RX_BYTE;
                        end
                    end
                end

                WRITE_PULSE: begin
                    o_reg_write_enable <= 1'b1;
                    state              <= WRITE_COMMIT;
                end

                WRITE_COMMIT: begin
                    tx_bytes[0] <= 8'hA1;
                    tx_index    <= 4'd0;
                    tx_length   <= 4'd1;
                    state       <= TX_SEND;
                end

                READ_CAPTURE: begin
                    o_last_read_1 <= i_reg_read_data_1;
                    tx_bytes[0]   <= i_reg_read_data_1[7:0];
                    tx_bytes[1]   <= i_reg_read_data_1[15:8];
                    tx_bytes[2]   <= i_reg_read_data_1[23:16];
                    tx_bytes[3]   <= i_reg_read_data_1[31:24];
                    tx_bytes[4]   <= i_reg_read_data_2[7:0];
                    tx_bytes[5]   <= i_reg_read_data_2[15:8];
                    tx_bytes[6]   <= i_reg_read_data_2[23:16];
                    tx_bytes[7]   <= i_reg_read_data_2[31:24];
                    tx_index      <= 4'd0;
                    tx_length     <= 4'd8;
                    state         <= TX_SEND;
                end

                PREPARE_ERROR: begin
                    tx_bytes[0] <= 8'hEE;
                    tx_index    <= 4'd0;
                    tx_length   <= 4'd1;
                    state       <= TX_SEND;
                end

                TX_SEND: begin
                    if (!i_tx_full) begin
                        o_w_data <= tx_bytes[tx_index];
                        o_wr     <= 1'b1;
                        state    <= TX_WAIT_FULL;
                    end
                end

                TX_WAIT_FULL: begin
                    if (i_tx_full)
                        state <= TX_WAIT_EMPTY;
                end

                TX_WAIT_EMPTY: begin
                    if (!i_tx_full) begin
                        if (tx_index == (tx_length - 1'b1)) begin
                            command  <= 8'h00;
                            rx_index <= 3'd0;
                            state    <= RX_BYTE;
                        end
                        else begin
                            tx_index <= tx_index + 1'b1;
                            state    <= TX_SEND;
                        end
                    end
                end

                default: begin
                    command  <= 8'h00;
                    rx_index <= 3'd0;
                    state    <= RX_BYTE;
                end
            endcase
        end
    end

endmodule
