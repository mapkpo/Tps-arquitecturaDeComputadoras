`timescale 1ns / 1ps

// Top incremental actual: primer pipeline RV32I, programable y observable por UART.
module top_tp_final #(
    parameter integer CLOCK_FREQ_HZ    = 90_000_000,
    parameter integer BAUD_RATE        = 115_200,
    parameter integer USE_CLOCK_MANAGER = 1,
    parameter integer MMCM_MULTIPLIER   = 9
)(
    input  wire       i_clk,
    input  wire       i_rst,
    input  wire       i_uart_rx,
    output wire       o_uart_tx,
    output wire [7:0] o_leds,
    output wire       o_rx_overrun,
    output wire       o_frame_error
);

    wire [7:0] rx_data;
    wire rx_empty, rx_read;
    wire [7:0] tx_data;
    wire tx_write, tx_full;

    wire imem_write_enable;
    wire [31:0] imem_write_addr, imem_write_data;
    wire imem_write_misaligned, imem_write_out_of_range;
    wire core_imem_read_enable;
    wire [31:0] core_imem_read_addr, imem_read_data;
    wire imem_read_misaligned, imem_read_out_of_range;

    wire core_dmem_read_enable, core_dmem_read_unsigned;
    wire [31:0] core_dmem_read_addr;
    wire [1:0] core_dmem_read_size;
    wire core_dmem_write_enable;
    wire [31:0] core_dmem_write_addr, core_dmem_write_data;
    wire [1:0] core_dmem_write_size;
    wire debug_dmem_read_enable, debug_dmem_read_unsigned;
    wire [31:0] debug_dmem_read_addr;
    wire [1:0] debug_dmem_read_size;
    wire [31:0] dmem_read_data;
    wire dmem_read_misaligned, dmem_read_out_of_range;
    logic [31:0] debug_dmem_read_data_q;
    logic debug_dmem_read_misaligned_q, debug_dmem_read_out_of_range_q;
    wire dmem_write_misaligned, dmem_write_out_of_range;
    wire dmem_read_enable, dmem_read_unsigned;
    wire [31:0] dmem_read_addr;
    wire [1:0] dmem_read_size;

    wire core_start, core_reset, core_enable, core_running, core_halted;
    wire [31:0] program_words;
    wire [4:0] debug_reg_addr;
    wire [31:0] debug_reg_data;
    wire [4:0] debug_snapshot_word_addr;
    wire [31:0] debug_snapshot_word_data;
    wire [3:0] core_stop_cause, pipeline_valid;
    wire [31:0] core_pc, core_cycles, core_retired;

    wire sys_clk;
    wire clock_locked;
    wire mmcm_clk_out;
    wire mmcm_clk_feedback_unbuffered;
    wire mmcm_clk_feedback;
    wire sys_rst = i_rst || !clock_locked;

    generate
        if (USE_CLOCK_MANAGER != 0) begin : GEN_CLOCK_80MHZ
            // Con divisor de salida 10: multiplicador 8 -> 80 MHz;
            // multiplicador 9 -> 90 MHz desde los 100 MHz de la Basys 3.
            MMCME2_BASE #(
                .BANDWIDTH("OPTIMIZED"),
                .CLKFBOUT_MULT_F(MMCM_MULTIPLIER),
                .CLKIN1_PERIOD(10.000),
                .CLKOUT0_DIVIDE_F(10.000),
                .DIVCLK_DIVIDE(1),
                .STARTUP_WAIT("FALSE")
            ) CLOCK_MANAGER (
                .CLKIN1(i_clk),
                .CLKFBIN(mmcm_clk_feedback),
                .RST(i_rst),
                .PWRDWN(1'b0),
                .CLKOUT0(mmcm_clk_out),
                .CLKFBOUT(mmcm_clk_feedback_unbuffered),
                .LOCKED(clock_locked)
            );
            BUFG CLOCK_OUTPUT_BUFFER (
                .I(mmcm_clk_out),
                .O(sys_clk)
            );
            BUFG CLOCK_FEEDBACK_BUFFER (
                .I(mmcm_clk_feedback_unbuffered),
                .O(mmcm_clk_feedback)
            );
        end
        else begin : GEN_CLOCK_BYPASS
            assign sys_clk = i_clk;
            assign clock_locked = 1'b1;
            assign mmcm_clk_out = 1'b0;
            assign mmcm_clk_feedback_unbuffered = 1'b0;
            assign mmcm_clk_feedback = 1'b0;
        end
    endgenerate

    assign dmem_read_enable   = debug_dmem_read_enable ? 1'b1
                                                       : core_dmem_read_enable;
    assign dmem_read_addr     = debug_dmem_read_enable ? debug_dmem_read_addr
                                                       : core_dmem_read_addr;
    assign dmem_read_size     = debug_dmem_read_enable ? debug_dmem_read_size
                                                       : core_dmem_read_size;
    assign dmem_read_unsigned = debug_dmem_read_enable ? debug_dmem_read_unsigned
                                                       : core_dmem_read_unsigned;
    assign o_leds = {core_halted, core_running && core_enable, core_stop_cause,
                     pipeline_valid[1:0]};

    // La respuesta UART se toma un ciclo después de la lectura de BRAM.
    // Así el camino de depuración no queda limitado a medio período.
    always_ff @(negedge sys_clk) begin
        if (sys_rst) begin
            debug_dmem_read_data_q         <= 32'd0;
            debug_dmem_read_misaligned_q   <= 1'b0;
            debug_dmem_read_out_of_range_q <= 1'b0;
        end
        else begin
            debug_dmem_read_data_q         <= dmem_read_data;
            debug_dmem_read_misaligned_q   <= dmem_read_misaligned;
            debug_dmem_read_out_of_range_q <= dmem_read_out_of_range;
        end
    end

    uart #(
        .CLOCK_FREQ_HZ(CLOCK_FREQ_HZ), .BAUD_RATE(BAUD_RATE),
        .DATA_BITS(8), .STOP_BITS(1), .OVERSAMPLE(16)
    ) UART (
        .i_clk(sys_clk), .i_rst(sys_rst), .i_rx(i_uart_rx), .o_tx(o_uart_tx),
        .o_r_data(rx_data), .i_rd(rx_read), .o_rx_empty(rx_empty),
        .i_w_data(tx_data), .i_wr(tx_write), .o_tx_full(tx_full),
        .o_rx_overrun(o_rx_overrun), .o_frame_error(o_frame_error)
    );

    pipeline_uart_smoke_controller CONTROLLER (
        .i_clk(sys_clk), .i_rst(sys_rst),
        .i_r_data(rx_data), .i_rx_empty(rx_empty), .o_rd(rx_read),
        .o_w_data(tx_data), .o_wr(tx_write), .i_tx_full(tx_full),
        .o_imem_write_enable(imem_write_enable),
        .o_imem_write_addr(imem_write_addr),
        .o_imem_write_data(imem_write_data),
        .i_imem_write_misaligned(imem_write_misaligned),
        .i_imem_write_out_of_range(imem_write_out_of_range),
        .o_core_start(core_start), .o_core_reset(core_reset),
        .o_core_enable(core_enable), .o_program_words(program_words),
        .i_core_running(core_running), .i_core_halted(core_halted),
        .i_core_stop_cause(core_stop_cause),
        .i_pipeline_valid(pipeline_valid),
        .i_core_pc(core_pc), .i_core_cycles(core_cycles),
        .i_core_retired(core_retired),
        .o_snapshot_word_addr(debug_snapshot_word_addr),
        .i_snapshot_word_data(debug_snapshot_word_data),
        .o_debug_reg_addr(debug_reg_addr),
        .i_debug_reg_data(debug_reg_data),
        .o_dmem_read_enable(debug_dmem_read_enable),
        .o_dmem_read_addr(debug_dmem_read_addr),
        .o_dmem_read_size(debug_dmem_read_size),
        .o_dmem_read_unsigned(debug_dmem_read_unsigned),
        .i_dmem_read_data(debug_dmem_read_data_q),
        .i_dmem_read_misaligned(debug_dmem_read_misaligned_q),
        .i_dmem_read_out_of_range(debug_dmem_read_out_of_range_q)
    );

    rv32_pipeline_core CORE (
        .i_clk(sys_clk), .i_rst(sys_rst || core_reset),
        .i_start(core_start), .i_enable(core_enable),
        .i_program_words(program_words),
        .o_imem_read_enable(core_imem_read_enable),
        .o_imem_read_addr(core_imem_read_addr),
        .i_imem_read_data(imem_read_data),
        .i_imem_read_misaligned(imem_read_misaligned),
        .i_imem_read_out_of_range(imem_read_out_of_range),
        .o_dmem_read_enable(core_dmem_read_enable),
        .o_dmem_read_addr(core_dmem_read_addr),
        .o_dmem_read_size(core_dmem_read_size),
        .o_dmem_read_unsigned(core_dmem_read_unsigned),
        .i_dmem_read_data(dmem_read_data),
        .i_dmem_read_misaligned(dmem_read_misaligned),
        .i_dmem_read_out_of_range(dmem_read_out_of_range),
        .o_dmem_write_enable(core_dmem_write_enable),
        .o_dmem_write_addr(core_dmem_write_addr),
        .o_dmem_write_size(core_dmem_write_size),
        .o_dmem_write_data(core_dmem_write_data),
        .i_dmem_write_misaligned(dmem_write_misaligned),
        .i_dmem_write_out_of_range(dmem_write_out_of_range),
        .i_debug_reg_addr(debug_reg_addr),
        .o_debug_reg_data(debug_reg_data),
        .i_debug_snapshot_word_addr(debug_snapshot_word_addr),
        .o_debug_snapshot_word_data(debug_snapshot_word_data),
        .o_running(core_running), .o_halted(core_halted),
        .o_stop_cause(core_stop_cause), .o_pc(core_pc),
        .o_cycle_count(core_cycles), .o_retired_count(core_retired),
        .o_pipeline_valid(pipeline_valid)
    );

    rv32_instruction_memory #(.WORDS(1024)) IMEM (
        .i_clk(sys_clk), .i_rst(sys_rst),
        .i_read_enable(core_imem_read_enable),
        .i_read_addr(core_imem_read_addr), .o_read_data(imem_read_data),
        .o_read_misaligned(imem_read_misaligned),
        .o_read_out_of_range(imem_read_out_of_range),
        .i_write_enable(imem_write_enable), .i_write_addr(imem_write_addr),
        .i_write_data(imem_write_data),
        .o_write_misaligned(imem_write_misaligned),
        .o_write_out_of_range(imem_write_out_of_range)
    );

    rv32_data_memory #(.WORDS(1024)) DMEM (
        .i_clk(sys_clk), .i_rst(sys_rst),
        .i_read_enable(dmem_read_enable), .i_read_addr(dmem_read_addr),
        .i_read_size(dmem_read_size), .i_read_unsigned(dmem_read_unsigned),
        .o_read_data(dmem_read_data),
        .o_read_misaligned(dmem_read_misaligned),
        .o_read_out_of_range(dmem_read_out_of_range),
        .i_write_enable(core_dmem_write_enable),
        .i_write_addr(core_dmem_write_addr),
        .i_write_size(core_dmem_write_size),
        .i_write_data(core_dmem_write_data),
        .o_write_misaligned(dmem_write_misaligned),
        .o_write_out_of_range(dmem_write_out_of_range)
    );

endmodule
