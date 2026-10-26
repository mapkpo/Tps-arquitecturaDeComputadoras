`timescale 1ns / 1ps

// Protocolo temporal de validación de memorias. Direcciones y datos: little-endian.
// 0x10 IMEM_WRITE: [cmd, addr(4), data(4)] -> [status]
// 0x11 IMEM_READ : [cmd, addr(4)]          -> [status, data(4)]
// 0x20 DMEM_WRITE: [cmd, size, addr(4), data(4)] -> [status]
// 0x21 DMEM_READ : [cmd, size, unsigned, addr(4)] -> [status, data(4)]
// status[0]=misaligned, status[1]=out_of_range.
module memory_uart_smoke_controller (
    input  logic        i_clk,
    input  logic        i_rst,
    input  logic [7:0]  i_r_data,
    input  logic        i_rx_empty,
    output logic        o_rd,
    output logic [7:0]  o_w_data,
    output logic        o_wr,
    input  logic        i_tx_full,

    output logic        o_imem_read_enable,
    output logic [31:0] o_imem_read_addr,
    input  logic [31:0] i_imem_read_data,
    input  logic        i_imem_read_misaligned,
    input  logic        i_imem_read_out_of_range,
    output logic        o_imem_write_enable,
    output logic [31:0] o_imem_write_addr,
    output logic [31:0] o_imem_write_data,
    input  logic        i_imem_write_misaligned,
    input  logic        i_imem_write_out_of_range,

    output logic        o_dmem_read_enable,
    output logic [31:0] o_dmem_read_addr,
    output logic [1:0]  o_dmem_read_size,
    output logic        o_dmem_read_unsigned,
    input  logic [31:0] i_dmem_read_data,
    input  logic        i_dmem_read_misaligned,
    input  logic        i_dmem_read_out_of_range,
    output logic        o_dmem_write_enable,
    output logic [31:0] o_dmem_write_addr,
    output logic [1:0]  o_dmem_write_size,
    output logic [31:0] o_dmem_write_data,
    input  logic        i_dmem_write_misaligned,
    input  logic        i_dmem_write_out_of_range,

    output logic [31:0] o_last_read_data
);

    localparam logic [7:0] CMD_IMEM_WRITE = 8'h10;
    localparam logic [7:0] CMD_IMEM_READ  = 8'h11;
    localparam logic [7:0] CMD_DMEM_WRITE = 8'h20;
    localparam logic [7:0] CMD_DMEM_READ  = 8'h21;

    typedef enum logic [3:0] {
        RX_BYTE,
        RX_WAIT_EMPTY,
        WRITE_PULSE,
        WRITE_COMMIT,
        READ_PULSE,
        READ_CAPTURE,
        PREPARE_ERROR,
        TX_SEND,
        TX_WAIT_FULL,
        TX_WAIT_EMPTY
    } state_t;

    state_t     state;
    logic [7:0] command;
    logic [3:0] rx_index;
    logic [3:0] expected_last_index;
    logic [2:0] tx_index;
    logic [2:0] tx_length;
    logic [7:0] tx_bytes [0:4];

    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            state                       <= RX_BYTE;
            command                     <= 8'h00;
            rx_index                    <= 4'd0;
            expected_last_index         <= 4'd0;
            tx_index                    <= 3'd0;
            tx_length                   <= 3'd0;
            o_rd                        <= 1'b0;
            o_wr                        <= 1'b0;
            o_w_data                    <= 8'h00;
            o_imem_read_enable          <= 1'b0;
            o_imem_read_addr            <= 32'd0;
            o_imem_write_enable         <= 1'b0;
            o_imem_write_addr           <= 32'd0;
            o_imem_write_data           <= 32'd0;
            o_dmem_read_enable          <= 1'b0;
            o_dmem_read_addr            <= 32'd0;
            o_dmem_read_size            <= 2'd2;
            o_dmem_read_unsigned        <= 1'b0;
            o_dmem_write_enable         <= 1'b0;
            o_dmem_write_addr           <= 32'd0;
            o_dmem_write_size           <= 2'd2;
            o_dmem_write_data           <= 32'd0;
            o_last_read_data            <= 32'd0;
        end
        else begin
            o_rd                <= 1'b0;
            o_wr                <= 1'b0;
            o_imem_read_enable  <= 1'b0;
            o_imem_write_enable <= 1'b0;
            o_dmem_read_enable  <= 1'b0;
            o_dmem_write_enable <= 1'b0;

            case (state)
                RX_BYTE: begin
                    if (!i_rx_empty) begin
                        if (rx_index == 4'd0) begin
                            command <= i_r_data;
                            case (i_r_data)
                                CMD_IMEM_WRITE: expected_last_index <= 4'd8;
                                CMD_IMEM_READ:  expected_last_index <= 4'd4;
                                CMD_DMEM_WRITE: expected_last_index <= 4'd9;
                                CMD_DMEM_READ:  expected_last_index <= 4'd6;
                                default:        expected_last_index <= 4'd0;
                            endcase
                        end
                        else begin
                            case (command)
                                CMD_IMEM_WRITE: begin
                                    case (rx_index)
                                        4'd1: o_imem_write_addr[7:0]   <= i_r_data;
                                        4'd2: o_imem_write_addr[15:8]  <= i_r_data;
                                        4'd3: o_imem_write_addr[23:16] <= i_r_data;
                                        4'd4: o_imem_write_addr[31:24] <= i_r_data;
                                        4'd5: o_imem_write_data[7:0]   <= i_r_data;
                                        4'd6: o_imem_write_data[15:8]  <= i_r_data;
                                        4'd7: o_imem_write_data[23:16] <= i_r_data;
                                        4'd8: o_imem_write_data[31:24] <= i_r_data;
                                        default: ;
                                    endcase
                                end
                                CMD_IMEM_READ: begin
                                    case (rx_index)
                                        4'd1: o_imem_read_addr[7:0]   <= i_r_data;
                                        4'd2: o_imem_read_addr[15:8]  <= i_r_data;
                                        4'd3: o_imem_read_addr[23:16] <= i_r_data;
                                        4'd4: o_imem_read_addr[31:24] <= i_r_data;
                                        default: ;
                                    endcase
                                end
                                CMD_DMEM_WRITE: begin
                                    case (rx_index)
                                        4'd1: o_dmem_write_size       <= i_r_data[1:0];
                                        4'd2: o_dmem_write_addr[7:0]   <= i_r_data;
                                        4'd3: o_dmem_write_addr[15:8]  <= i_r_data;
                                        4'd4: o_dmem_write_addr[23:16] <= i_r_data;
                                        4'd5: o_dmem_write_addr[31:24] <= i_r_data;
                                        4'd6: o_dmem_write_data[7:0]   <= i_r_data;
                                        4'd7: o_dmem_write_data[15:8]  <= i_r_data;
                                        4'd8: o_dmem_write_data[23:16] <= i_r_data;
                                        4'd9: o_dmem_write_data[31:24] <= i_r_data;
                                        default: ;
                                    endcase
                                end
                                CMD_DMEM_READ: begin
                                    case (rx_index)
                                        4'd1: o_dmem_read_size        <= i_r_data[1:0];
                                        4'd2: o_dmem_read_unsigned    <= i_r_data[0];
                                        4'd3: o_dmem_read_addr[7:0]   <= i_r_data;
                                        4'd4: o_dmem_read_addr[15:8]  <= i_r_data;
                                        4'd5: o_dmem_read_addr[23:16] <= i_r_data;
                                        4'd6: o_dmem_read_addr[31:24] <= i_r_data;
                                        default: ;
                                    endcase
                                end
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
                                CMD_IMEM_WRITE, CMD_DMEM_WRITE: state <= WRITE_PULSE;
                                CMD_IMEM_READ, CMD_DMEM_READ:   state <= READ_PULSE;
                                default:                        state <= PREPARE_ERROR;
                            endcase
                        end
                        else begin
                            rx_index <= rx_index + 1'b1;
                            state    <= RX_BYTE;
                        end
                    end
                end

                WRITE_PULSE: begin
                    if (command == CMD_IMEM_WRITE)
                        o_imem_write_enable <= 1'b1;
                    else
                        o_dmem_write_enable <= 1'b1;
                    state <= WRITE_COMMIT;
                end

                WRITE_COMMIT: begin
                    if (command == CMD_IMEM_WRITE)
                        tx_bytes[0] <= {6'b000000, i_imem_write_out_of_range,
                                       i_imem_write_misaligned};
                    else
                        tx_bytes[0] <= {6'b000000, i_dmem_write_out_of_range,
                                       i_dmem_write_misaligned};
                    tx_index  <= 3'd0;
                    tx_length <= 3'd1;
                    state     <= TX_SEND;
                end

                READ_PULSE: begin
                    if (command == CMD_IMEM_READ)
                        o_imem_read_enable <= 1'b1;
                    else
                        o_dmem_read_enable <= 1'b1;
                    state <= READ_CAPTURE;
                end

                READ_CAPTURE: begin
                    if (command == CMD_IMEM_READ) begin
                        tx_bytes[0] <= {6'b000000, i_imem_read_out_of_range,
                                       i_imem_read_misaligned};
                        tx_bytes[1] <= i_imem_read_data[7:0];
                        tx_bytes[2] <= i_imem_read_data[15:8];
                        tx_bytes[3] <= i_imem_read_data[23:16];
                        tx_bytes[4] <= i_imem_read_data[31:24];
                        o_last_read_data <= i_imem_read_data;
                    end
                    else begin
                        tx_bytes[0] <= {6'b000000, i_dmem_read_out_of_range,
                                       i_dmem_read_misaligned};
                        tx_bytes[1] <= i_dmem_read_data[7:0];
                        tx_bytes[2] <= i_dmem_read_data[15:8];
                        tx_bytes[3] <= i_dmem_read_data[23:16];
                        tx_bytes[4] <= i_dmem_read_data[31:24];
                        o_last_read_data <= i_dmem_read_data;
                    end
                    tx_index  <= 3'd0;
                    tx_length <= 3'd5;
                    state     <= TX_SEND;
                end

                PREPARE_ERROR: begin
                    tx_bytes[0] <= 8'hFF;
                    tx_index    <= 3'd0;
                    tx_length   <= 3'd1;
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
                    command  <= 8'h00;
                    rx_index <= 4'd0;
                    state    <= RX_BYTE;
                end
            endcase
        end
    end

endmodule
