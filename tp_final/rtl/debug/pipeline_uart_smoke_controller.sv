`timescale 1ns / 1ps

// Protocolo temporal para validar el primer pipeline en placa.
// 0x10 LOAD_WORD [addr(4), data(4)] -> [status]
// 0x20 RUN       [program_words(4)] -> [status]
// 0x21 STATUS                       -> [running,halted,cause,valid,pc,cycles,retired]
// 0x22 READ_REG  [address]          -> [status,data(4)]
// 0x23 READ_DMEM [size,unsigned,addr(4)] -> [status,data(4)]
// 0x24 START_PAUSED [program_words(4)] -> [status]
// 0x25 STEP                          -> [status]
// 0x26 PAUSE                         -> [status]
// 0x27 RESUME                        -> [status]
// 0x28 RESET_CORE                    -> [status]
// 0x29 SNAPSHOT                      -> [status, 32 words little-endian]
module pipeline_uart_smoke_controller (
    input  logic        i_clk,
    input  logic        i_rst,
    input  logic [7:0]  i_r_data,
    input  logic        i_rx_empty,
    output logic        o_rd,
    output logic [7:0]  o_w_data,
    output logic        o_wr,
    input  logic        i_tx_full,

    output logic        o_imem_write_enable,
    output logic [31:0] o_imem_write_addr,
    output logic [31:0] o_imem_write_data,
    input  logic        i_imem_write_misaligned,
    input  logic        i_imem_write_out_of_range,

    output logic        o_core_start,
    output logic        o_core_reset,
    output logic        o_core_enable,
    output logic [31:0] o_program_words,
    input  logic        i_core_running,
    input  logic        i_core_halted,
    input  logic [3:0]  i_core_stop_cause,
    input  logic [3:0]  i_pipeline_valid,
    input  logic [31:0] i_core_pc,
    input  logic [31:0] i_core_cycles,
    input  logic [31:0] i_core_retired,
    output logic [4:0]  o_snapshot_word_addr,
    input  logic [31:0] i_snapshot_word_data,

    output logic [4:0]  o_debug_reg_addr,
    input  logic [31:0] i_debug_reg_data,

    output logic        o_dmem_read_enable,
    output logic [31:0] o_dmem_read_addr,
    output logic [1:0]  o_dmem_read_size,
    output logic        o_dmem_read_unsigned,
    input  logic [31:0] i_dmem_read_data,
    input  logic        i_dmem_read_misaligned,
    input  logic        i_dmem_read_out_of_range
);

    localparam logic [7:0] CMD_LOAD_WORD = 8'h10;
    localparam logic [7:0] CMD_RUN       = 8'h20;
    localparam logic [7:0] CMD_STATUS    = 8'h21;
    localparam logic [7:0] CMD_READ_REG  = 8'h22;
    localparam logic [7:0] CMD_READ_DMEM = 8'h23;
    localparam logic [7:0] CMD_START_PAUSED = 8'h24;
    localparam logic [7:0] CMD_STEP         = 8'h25;
    localparam logic [7:0] CMD_PAUSE        = 8'h26;
    localparam logic [7:0] CMD_RESUME       = 8'h27;
    localparam logic [7:0] CMD_RESET_CORE   = 8'h28;
    localparam logic [7:0] CMD_SNAPSHOT     = 8'h29;

    typedef enum logic [4:0] {
        RX_BYTE,
        RX_WAIT_EMPTY,
        LOAD_PULSE,
        LOAD_COMMIT,
        RUN_PULSE,
        RUN_ACK,
        PREPARE_STATUS,
        PREPARE_REGISTER,
        DMEM_READ_PULSE,
        DMEM_READ_WAIT,
        DMEM_READ_CAPTURE,
        CONTROL_APPLY,
        CONTROL_ACK,
        PREPARE_SNAPSHOT,
        PREPARE_ERROR,
        TX_SEND,
        TX_WAIT_FULL,
        TX_WAIT_EMPTY
    } state_t;

    state_t state;
    logic [7:0] command;
    logic [3:0] rx_index;
    logic [3:0] expected_last_index;
    logic [7:0] tx_index;
    logic [7:0] tx_length;
    logic [7:0] tx_bytes [0:15];
    logic       invalid_reg_address;
    logic [7:0] control_status;
    logic [7:0] snapshot_status;
    logic [7:0] snapshot_byte_index;
    logic [7:0] snapshot_word_byte;
    wire core_active = i_core_running && o_core_enable;
    wire core_paused = i_core_running && !o_core_enable;

    always_comb begin
        snapshot_byte_index = tx_index - 8'd1;
        o_snapshot_word_addr = snapshot_byte_index[6:2];
        case (snapshot_byte_index[1:0])
            2'd0: snapshot_word_byte = i_snapshot_word_data[7:0];
            2'd1: snapshot_word_byte = i_snapshot_word_data[15:8];
            2'd2: snapshot_word_byte = i_snapshot_word_data[23:16];
            default: snapshot_word_byte = i_snapshot_word_data[31:24];
        endcase
    end

    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            state                    <= RX_BYTE;
            command                  <= 8'h00;
            rx_index                 <= 4'd0;
            expected_last_index      <= 4'd0;
            tx_index                 <= 8'd0;
            tx_length                <= 8'd0;
            o_rd                     <= 1'b0;
            o_wr                     <= 1'b0;
            o_w_data                 <= 8'h00;
            o_imem_write_enable      <= 1'b0;
            o_imem_write_addr        <= 32'd0;
            o_imem_write_data        <= 32'd0;
            o_core_start             <= 1'b0;
            o_core_reset             <= 1'b0;
            o_core_enable            <= 1'b0;
            o_program_words          <= 32'd0;
            o_debug_reg_addr         <= 5'd0;
            invalid_reg_address      <= 1'b0;
            control_status           <= 8'h00;
            snapshot_status          <= 8'h00;
            o_dmem_read_enable       <= 1'b0;
            o_dmem_read_addr         <= 32'd0;
            o_dmem_read_size         <= 2'd2;
            o_dmem_read_unsigned     <= 1'b0;
        end
        else begin
            o_rd                <= 1'b0;
            o_wr                <= 1'b0;
            o_imem_write_enable <= 1'b0;
            o_core_start        <= 1'b0;
            o_core_reset        <= 1'b0;
            o_dmem_read_enable  <= 1'b0;

            case (state)
                RX_BYTE: begin
                    if (!i_rx_empty) begin
                        if (rx_index == 4'd0) begin
                            command <= i_r_data;
                            case (i_r_data)
                                CMD_LOAD_WORD: expected_last_index <= 4'd8;
                                CMD_RUN:       expected_last_index <= 4'd4;
                                CMD_STATUS:    expected_last_index <= 4'd0;
                                CMD_READ_REG:  expected_last_index <= 4'd1;
                                CMD_READ_DMEM: expected_last_index <= 4'd6;
                                CMD_START_PAUSED: expected_last_index <= 4'd4;
                                CMD_STEP:       expected_last_index <= 4'd0;
                                CMD_PAUSE:      expected_last_index <= 4'd0;
                                CMD_RESUME:     expected_last_index <= 4'd0;
                                CMD_RESET_CORE: expected_last_index <= 4'd0;
                                CMD_SNAPSHOT:   expected_last_index <= 4'd0;
                                default:       expected_last_index <= 4'd0;
                            endcase
                        end
                        else begin
                            case (command)
                                CMD_LOAD_WORD: begin
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
                                CMD_RUN, CMD_START_PAUSED: begin
                                    case (rx_index)
                                        4'd1: o_program_words[7:0]   <= i_r_data;
                                        4'd2: o_program_words[15:8]  <= i_r_data;
                                        4'd3: o_program_words[23:16] <= i_r_data;
                                        4'd4: o_program_words[31:24] <= i_r_data;
                                        default: ;
                                    endcase
                                end
                                CMD_READ_REG: begin
                                    o_debug_reg_addr    <= i_r_data[4:0];
                                    invalid_reg_address <= |i_r_data[7:5];
                                end
                                CMD_READ_DMEM: begin
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
                                CMD_LOAD_WORD: state <= LOAD_PULSE;
                                CMD_RUN:       state <= RUN_PULSE;
                                CMD_STATUS:    state <= PREPARE_STATUS;
                                CMD_READ_REG:  state <= PREPARE_REGISTER;
                                CMD_READ_DMEM: state <= DMEM_READ_PULSE;
                                CMD_START_PAUSED,
                                CMD_STEP,
                                CMD_PAUSE,
                                 CMD_RESUME,
                                 CMD_RESET_CORE: state <= CONTROL_APPLY;
                                 CMD_SNAPSHOT:   state <= PREPARE_SNAPSHOT;
                                default:       state <= PREPARE_ERROR;
                            endcase
                        end
                        else begin
                            rx_index <= rx_index + 1'b1;
                            state <= RX_BYTE;
                        end
                    end
                end

                LOAD_PULSE: begin
                    if (!i_core_running)
                        o_imem_write_enable <= 1'b1;
                    state <= LOAD_COMMIT;
                end

                LOAD_COMMIT: begin
                    if (i_core_running)
                        tx_bytes[0] <= 8'h80;
                    else
                        tx_bytes[0] <= {6'b000000, i_imem_write_out_of_range,
                                       i_imem_write_misaligned};
                    tx_index <= 8'd0;
                    tx_length <= 8'd1;
                    state <= TX_SEND;
                end

                RUN_PULSE: begin
                    if (!i_core_running && (o_program_words != 32'd0) &&
                        (o_program_words <= 32'd1024)) begin
                        o_core_start <= 1'b1;
                        o_core_enable <= 1'b1;
                    end
                    state <= RUN_ACK;
                end

                RUN_ACK: begin
                    if (i_core_running)
                        tx_bytes[0] <= 8'h80;
                    else if ((o_program_words == 32'd0) ||
                             (o_program_words > 32'd1024))
                        tx_bytes[0] <= 8'h02;
                    else
                        tx_bytes[0] <= 8'h00;
                    tx_index <= 8'd0;
                    tx_length <= 8'd1;
                    state <= TX_SEND;
                end

                PREPARE_STATUS: begin
                    tx_bytes[0]  <= {7'd0, core_active};
                    tx_bytes[1]  <= {6'd0, core_paused, i_core_halted};
                    tx_bytes[2]  <= {4'd0, i_core_stop_cause};
                    tx_bytes[3]  <= {4'd0, i_pipeline_valid};
                    tx_bytes[4]  <= i_core_pc[7:0];
                    tx_bytes[5]  <= i_core_pc[15:8];
                    tx_bytes[6]  <= i_core_pc[23:16];
                    tx_bytes[7]  <= i_core_pc[31:24];
                    tx_bytes[8]  <= i_core_cycles[7:0];
                    tx_bytes[9]  <= i_core_cycles[15:8];
                    tx_bytes[10] <= i_core_cycles[23:16];
                    tx_bytes[11] <= i_core_cycles[31:24];
                    tx_bytes[12] <= i_core_retired[7:0];
                    tx_bytes[13] <= i_core_retired[15:8];
                    tx_bytes[14] <= i_core_retired[23:16];
                    tx_bytes[15] <= i_core_retired[31:24];
                    tx_index <= 8'd0;
                    tx_length <= 8'd16;
                    state <= TX_SEND;
                end

                PREPARE_REGISTER: begin
                    if (core_active)
                        tx_bytes[0] <= 8'h80;
                    else if (invalid_reg_address)
                        tx_bytes[0] <= 8'h02;
                    else
                        tx_bytes[0] <= 8'h00;
                    tx_bytes[1] <= (core_active || invalid_reg_address)
                        ? 8'h00 : i_debug_reg_data[7:0];
                    tx_bytes[2] <= (core_active || invalid_reg_address)
                        ? 8'h00 : i_debug_reg_data[15:8];
                    tx_bytes[3] <= (core_active || invalid_reg_address)
                        ? 8'h00 : i_debug_reg_data[23:16];
                    tx_bytes[4] <= (core_active || invalid_reg_address)
                        ? 8'h00 : i_debug_reg_data[31:24];
                    tx_index <= 8'd0;
                    tx_length <= 8'd5;
                    state <= TX_SEND;
                end

                DMEM_READ_PULSE: begin
                    if (!core_active)
                        o_dmem_read_enable <= 1'b1;
                    state <= DMEM_READ_WAIT;
                end

                DMEM_READ_WAIT: begin
                    state <= DMEM_READ_CAPTURE;
                end

                DMEM_READ_CAPTURE: begin
                    if (core_active)
                        tx_bytes[0] <= 8'h80;
                    else
                        tx_bytes[0] <= {6'b000000, i_dmem_read_out_of_range,
                                       i_dmem_read_misaligned};
                    tx_bytes[1] <= core_active ? 8'h00 : i_dmem_read_data[7:0];
                    tx_bytes[2] <= core_active ? 8'h00 : i_dmem_read_data[15:8];
                    tx_bytes[3] <= core_active ? 8'h00 : i_dmem_read_data[23:16];
                    tx_bytes[4] <= core_active ? 8'h00 : i_dmem_read_data[31:24];
                    tx_index <= 8'd0;
                    tx_length <= 8'd5;
                    state <= TX_SEND;
                end

                CONTROL_APPLY: begin
                    control_status <= 8'h00;
                    case (command)
                        CMD_START_PAUSED: begin
                            if (i_core_running)
                                control_status <= 8'h80;
                            else if ((o_program_words == 32'd0) ||
                                     (o_program_words > 32'd1024))
                                control_status <= 8'h02;
                            else begin
                                o_core_enable <= 1'b0;
                                o_core_start <= 1'b1;
                            end
                        end
                        CMD_STEP: begin
                            if (!i_core_running || i_core_halted ||
                                o_core_enable)
                                control_status <= 8'h80;
                            else
                                o_core_enable <= 1'b1;
                        end
                        CMD_PAUSE: begin
                            if (!i_core_running || i_core_halted)
                                control_status <= 8'h80;
                            else
                                o_core_enable <= 1'b0;
                        end
                        CMD_RESUME: begin
                            if (!i_core_running || i_core_halted)
                                control_status <= 8'h80;
                            else
                                o_core_enable <= 1'b1;
                        end
                        CMD_RESET_CORE: begin
                            o_core_enable <= 1'b0;
                            o_core_reset <= 1'b1;
                        end
                        default: control_status <= 8'hFF;
                    endcase
                    state <= CONTROL_ACK;
                end

                CONTROL_ACK: begin
                    // STEP mantiene enable alto durante exactamente un flanco.
                    if ((command == CMD_STEP) && (control_status == 8'h00))
                        o_core_enable <= 1'b0;
                    tx_bytes[0] <= control_status;
                    tx_index <= 8'd0;
                    tx_length <= 8'd1;
                    state <= TX_SEND;
                end

                PREPARE_SNAPSHOT: begin
                    // Con el core activo la captura no sería coherente. Pausado,
                    // detenido o inactivo, los 32 words permanecen estables.
                    snapshot_status <= core_active ? 8'h80 : 8'h00;
                    tx_index <= 8'd0;
                    tx_length <= core_active ? 8'd1 : 8'd129;
                    state <= TX_SEND;
                end

                PREPARE_ERROR: begin
                    tx_bytes[0] <= 8'hFF;
                    tx_index <= 8'd0;
                    tx_length <= 8'd1;
                    state <= TX_SEND;
                end

                TX_SEND: begin
                    if (!i_tx_full) begin
                        if (command == CMD_SNAPSHOT)
                            o_w_data <= (tx_index == 8'd0)
                                ? snapshot_status : snapshot_word_byte;
                        else
                            o_w_data <= tx_bytes[tx_index[4:0]];
                        o_wr <= 1'b1;
                        state <= TX_WAIT_FULL;
                    end
                end

                TX_WAIT_FULL: begin
                    if (i_tx_full)
                        state <= TX_WAIT_EMPTY;
                end

                TX_WAIT_EMPTY: begin
                    if (!i_tx_full) begin
                        if (tx_index == (tx_length - 1'b1)) begin
                            command <= 8'h00;
                            rx_index <= 4'd0;
                            state <= RX_BYTE;
                        end
                        else begin
                            tx_index <= tx_index + 1'b1;
                            state <= TX_SEND;
                        end
                    end
                end

                default: begin
                    command <= 8'h00;
                    rx_index <= 4'd0;
                    state <= RX_BYTE;
                end
            endcase
        end
    end

endmodule
