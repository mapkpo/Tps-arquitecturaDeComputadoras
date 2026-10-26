`timescale 1ns / 1ps

// Protocolo temporal para validar decoder + inmediatos en placa.
// DECODE 0x03: [cmd, instruction0..instruction3] -> 14 bytes:
// status, rs1, rs2, rd, alu_op, imm_type, mem_ctrl, branch, jump, wb_sel,
// immediate0..immediate3. Todos los valores multibyte son little-endian.
module decoder_uart_smoke_controller (
    input  logic        i_clk,
    input  logic        i_rst,
    input  logic [7:0]  i_r_data,
    input  logic        i_rx_empty,
    output logic        o_rd,
    output logic [7:0]  o_w_data,
    output logic        o_wr,
    input  logic        i_tx_full,

    output logic [31:0] o_instruction,
    input  logic [4:0]  i_rs1,
    input  logic [4:0]  i_rs2,
    input  logic [4:0]  i_rd,
    input  logic        i_legal,
    input  logic        i_halt,
    input  logic        i_uses_rs1,
    input  logic        i_uses_rs2,
    input  logic        i_reg_write,
    input  logic        i_alu_src_imm,
    input  logic [3:0]  i_alu_op,
    input  logic [2:0]  i_imm_type,
    input  logic        i_mem_read,
    input  logic        i_mem_write,
    input  logic [1:0]  i_mem_size,
    input  logic        i_mem_unsigned,
    input  logic [1:0]  i_branch,
    input  logic [1:0]  i_jump,
    input  logic [1:0]  i_wb_sel,
    input  logic [31:0] i_immediate
);

    localparam logic [7:0] CMD_DECODE = 8'h03;

    typedef enum logic [2:0] {
        RX_BYTE,
        RX_WAIT_EMPTY,
        CAPTURE_RESULT,
        PREPARE_ERROR,
        TX_SEND,
        TX_WAIT_FULL,
        TX_WAIT_EMPTY
    } state_t;

    state_t     state;
    logic [7:0] command;
    logic [2:0] rx_index;
    logic [4:0] tx_index;
    logic [4:0] tx_length;
    logic [7:0] tx_bytes [0:13];

    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            state         <= RX_BYTE;
            command       <= 8'h00;
            rx_index      <= 3'd0;
            tx_index      <= 5'd0;
            tx_length     <= 5'd0;
            o_rd          <= 1'b0;
            o_wr          <= 1'b0;
            o_w_data      <= 8'h00;
            o_instruction <= 32'h0000_0013;
        end
        else begin
            o_rd <= 1'b0;
            o_wr <= 1'b0;

            case (state)
                RX_BYTE: begin
                    if (!i_rx_empty) begin
                        if (rx_index == 3'd0)
                            command <= i_r_data;
                        else if (command == CMD_DECODE) begin
                            case (rx_index)
                                3'd1: o_instruction[7:0]   <= i_r_data;
                                3'd2: o_instruction[15:8]  <= i_r_data;
                                3'd3: o_instruction[23:16] <= i_r_data;
                                3'd4: o_instruction[31:24] <= i_r_data;
                                default: ;
                            endcase
                        end
                        o_rd  <= 1'b1;
                        state <= RX_WAIT_EMPTY;
                    end
                end

                RX_WAIT_EMPTY: begin
                    if (i_rx_empty) begin
                        if (rx_index == 3'd0 && command != CMD_DECODE)
                            state <= PREPARE_ERROR;
                        else if (rx_index == 3'd4)
                            state <= CAPTURE_RESULT;
                        else begin
                            rx_index <= rx_index + 1'b1;
                            state    <= RX_BYTE;
                        end
                    end
                end

                CAPTURE_RESULT: begin
                    tx_bytes[0]  <= {i_alu_src_imm, i_mem_write, i_mem_read,
                                     i_reg_write, i_uses_rs2, i_uses_rs1,
                                     i_halt, i_legal};
                    tx_bytes[1]  <= {3'b000, i_rs1};
                    tx_bytes[2]  <= {3'b000, i_rs2};
                    tx_bytes[3]  <= {3'b000, i_rd};
                    tx_bytes[4]  <= {4'b0000, i_alu_op};
                    tx_bytes[5]  <= {5'b00000, i_imm_type};
                    tx_bytes[6]  <= {5'b00000, i_mem_unsigned, i_mem_size};
                    tx_bytes[7]  <= {6'b000000, i_branch};
                    tx_bytes[8]  <= {6'b000000, i_jump};
                    tx_bytes[9]  <= {6'b000000, i_wb_sel};
                    tx_bytes[10] <= i_immediate[7:0];
                    tx_bytes[11] <= i_immediate[15:8];
                    tx_bytes[12] <= i_immediate[23:16];
                    tx_bytes[13] <= i_immediate[31:24];
                    tx_index     <= 5'd0;
                    tx_length    <= 5'd14;
                    state        <= TX_SEND;
                end

                PREPARE_ERROR: begin
                    tx_bytes[0] <= 8'hEE;
                    tx_index    <= 5'd0;
                    tx_length   <= 5'd1;
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
