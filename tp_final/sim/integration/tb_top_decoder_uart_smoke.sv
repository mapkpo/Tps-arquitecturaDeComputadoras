`timescale 1ns / 1ps

module tb_top_decoder_uart_smoke;

    localparam integer CLOCK_FREQ_HZ = 16_000_000;
    localparam integer BAUD_RATE     = 1_000_000;
    localparam integer OVERSAMPLE    = 16;

    logic      clk;
    logic      rst;
    logic      uart_rx;
    wire       uart_tx;
    wire [7:0] leds;
    wire       rx_overrun;
    wire       frame_error;
    integer    errors;

    top_decoder_uart_smoke #(
        .CLOCK_FREQ_HZ(CLOCK_FREQ_HZ), .BAUD_RATE(BAUD_RATE)
    ) DUT (
        .i_clk(clk), .i_rst(rst),
        .i_uart_rx(uart_rx), .o_uart_tx(uart_tx),
        .o_leds(leds),
        .o_rx_overrun(rx_overrun), .o_frame_error(frame_error)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    function automatic logic [31:0] encode_r(
        input logic [6:0] funct7_value,
        input logic [2:0] funct3_value
    );
        encode_r = {funct7_value, 5'd2, 5'd1, funct3_value, 5'd3, 7'h33};
    endfunction

    function automatic logic [31:0] encode_i(
        input logic [11:0] imm,
        input logic [2:0] funct3_value,
        input logic [6:0] opcode_value
    );
        encode_i = {imm, 5'd1, funct3_value, 5'd3, opcode_value};
    endfunction

    function automatic logic [31:0] encode_s(
        input logic [11:0] imm,
        input logic [2:0] funct3_value
    );
        encode_s = {imm[11:5], 5'd2, 5'd1, funct3_value, imm[4:0], 7'h23};
    endfunction

    function automatic logic [31:0] encode_b(
        input logic [12:0] imm,
        input logic [2:0] funct3_value
    );
        encode_b = {imm[12], imm[10:5], 5'd2, 5'd1, funct3_value,
                    imm[4:1], imm[11], 7'h63};
    endfunction

    function automatic logic [31:0] encode_j(input logic [20:0] imm);
        encode_j = {imm[20], imm[10:1], imm[11], imm[19:12], 5'd3, 7'h6F};
    endfunction

    task automatic wait_clocks(input integer count);
        integer n;
        begin
            for (n = 0; n < count; n = n + 1)
                @(posedge clk);
        end
    endtask

    task automatic send_uart_byte(input logic [7:0] value);
        integer n;
        begin
            uart_rx = 1'b0;
            wait_clocks(OVERSAMPLE);
            for (n = 0; n < 8; n = n + 1) begin
                uart_rx = value[n];
                wait_clocks(OVERSAMPLE);
            end
            uart_rx = 1'b1;
            wait_clocks(OVERSAMPLE);
        end
    endtask

    task automatic receive_uart_byte(output logic [7:0] value);
        integer n;
        begin
            @(negedge uart_tx);
            wait_clocks(OVERSAMPLE / 2);
            for (n = 0; n < 8; n = n + 1) begin
                wait_clocks(OVERSAMPLE);
                value[n] = uart_tx;
            end
            wait_clocks(OVERSAMPLE);
            if (uart_tx !== 1'b1) begin
                errors = errors + 1;
                $display("ERROR: bit de stop inválido");
            end
        end
    endtask

    task automatic receive_and_check(
        input string name,
        input logic [7:0] expected_status,
        input logic [4:0] expected_rs1,
        input logic [4:0] expected_rs2,
        input logic [4:0] expected_rd,
        input logic [3:0] expected_alu,
        input logic [2:0] expected_imm_type,
        input logic [2:0] expected_mem_ctrl,
        input logic [1:0] expected_branch,
        input logic [1:0] expected_jump,
        input logic [1:0] expected_wb,
        input logic [31:0] expected_immediate
    );
        logic [7:0] actual;
        logic [7:0] expected [0:13];
        integer index;
        begin
            expected[0]  = expected_status;
            expected[1]  = {3'b000, expected_rs1};
            expected[2]  = {3'b000, expected_rs2};
            expected[3]  = {3'b000, expected_rd};
            expected[4]  = {4'b0000, expected_alu};
            expected[5]  = {5'b00000, expected_imm_type};
            expected[6]  = {5'b00000, expected_mem_ctrl};
            expected[7]  = {6'b000000, expected_branch};
            expected[8]  = {6'b000000, expected_jump};
            expected[9]  = {6'b000000, expected_wb};
            expected[10] = expected_immediate[7:0];
            expected[11] = expected_immediate[15:8];
            expected[12] = expected_immediate[23:16];
            expected[13] = expected_immediate[31:24];

            for (index = 0; index < 14; index = index + 1) begin
                receive_uart_byte(actual);
                if (actual !== expected[index]) begin
                    errors = errors + 1;
                    $display("ERROR %-8s byte %0d: esperado=%02h obtenido=%02h",
                             name, index, expected[index], actual);
                end
            end
        end
    endtask

    task automatic decode_and_check(
        input string name,
        input logic [31:0] value,
        input logic [7:0] expected_status,
        input logic [3:0] expected_alu,
        input logic [2:0] expected_imm_type,
        input logic [2:0] expected_mem_ctrl,
        input logic [1:0] expected_branch,
        input logic [1:0] expected_jump,
        input logic [1:0] expected_wb,
        input logic [31:0] expected_immediate
    );
        begin
            send_uart_byte(8'h03);
            send_uart_byte(value[7:0]);
            send_uart_byte(value[15:8]);
            send_uart_byte(value[23:16]);
            fork
                send_uart_byte(value[31:24]);
                receive_and_check(name, expected_status,
                    value[19:15], value[24:20], value[11:7], expected_alu,
                    expected_imm_type, expected_mem_ctrl, expected_branch,
                    expected_jump, expected_wb, expected_immediate);
            join

            if (leds !== value[7:0]) begin
                errors = errors + 1;
                $display("ERROR LEDs %-8s: esperado=%02h obtenido=%02h",
                         name, value[7:0], leds);
            end
        end
    endtask

    initial begin
        rst = 1'b1;
        uart_rx = 1'b1;
        errors = 0;
        wait_clocks(5);
        rst = 1'b0;
        wait_clocks(5);

        decode_and_check("ADD", encode_r(7'h00, 3'b000), 8'h1D,
            4'h0, 3'd0, 3'd2, 2'd0, 2'd0, 2'd0, 32'd0);
        decode_and_check("SRA", encode_r(7'h20, 3'b101), 8'h1D,
            4'h4, 3'd0, 3'd2, 2'd0, 2'd0, 2'd0, 32'd0);
        decode_and_check("ADDI", encode_i(12'hFF0, 3'b000, 7'h13), 8'h95,
            4'h0, 3'd1, 3'd2, 2'd0, 2'd0, 2'd0, 32'hFFFF_FFF0);
        decode_and_check("LW", encode_i(12'hFF8, 3'b010, 7'h03), 8'hB5,
            4'h0, 3'd1, 3'd2, 2'd0, 2'd0, 2'd1, 32'hFFFF_FFF8);
        decode_and_check("SW", encode_s(12'hFF4, 3'b010), 8'hCD,
            4'h0, 3'd2, 3'd2, 2'd0, 2'd0, 2'd0, 32'hFFFF_FFF4);
        decode_and_check("BNE", encode_b(13'h1FFC, 3'b001), 8'h0D,
            4'h1, 3'd3, 3'd2, 2'd2, 2'd0, 2'd0, 32'hFFFF_FFFC);
        decode_and_check("LUI", {20'hABCDE, 5'd3, 7'h37}, 8'h91,
            4'hA, 3'd4, 3'd2, 2'd0, 2'd0, 2'd0, 32'hABCDE000);
        decode_and_check("JAL", encode_j(21'h1F_FFF8), 8'h11,
            4'h0, 3'd5, 3'd2, 2'd0, 2'd1, 2'd2, 32'hFFFF_FFF8);
        decode_and_check("JALR", encode_i(12'h00C, 3'b000, 7'h67), 8'h95,
            4'h0, 3'd1, 3'd2, 2'd0, 2'd2, 2'd2, 32'h0000_000C);
        decode_and_check("EBREAK", 32'h0010_0073, 8'h03,
            4'h0, 3'd0, 3'd2, 2'd0, 2'd0, 2'd0, 32'd0);
        decode_and_check("ILLEGAL", 32'h0000_0000, 8'h00,
            4'h0, 3'd0, 3'd2, 2'd0, 2'd0, 2'd0, 32'd0);

        if (rx_overrun || frame_error) begin
            errors = errors + 1;
            $display("ERROR: flag UART inesperado");
        end

        if (errors == 0)
            $display("RESULTADO: INTEGRACION UART-DECODER RV32I OK");
        else
            $fatal(1, "RESULTADO: %0d ERRORES", errors);

        $finish;
    end

endmodule
