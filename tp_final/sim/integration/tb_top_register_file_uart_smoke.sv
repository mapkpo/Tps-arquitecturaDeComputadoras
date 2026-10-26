`timescale 1ns / 1ps

module tb_top_register_file_uart_smoke;

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

    top_register_file_uart_smoke #(
        .CLOCK_FREQ_HZ(CLOCK_FREQ_HZ),
        .BAUD_RATE(BAUD_RATE)
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

    task automatic write_register(input logic [4:0] address, input logic [31:0] value);
        logic [7:0] ack;
        begin
            send_uart_byte(8'h01);
            send_uart_byte({3'b000, address});
            send_uart_byte(value[7:0]);
            send_uart_byte(value[15:8]);
            send_uart_byte(value[23:16]);
            fork
                send_uart_byte(value[31:24]);
                receive_uart_byte(ack);
            join
            if (ack !== 8'hA1) begin
                errors = errors + 1;
                $display("ERROR ACK escritura x%0d: %h", address, ack);
            end
        end
    endtask

    task automatic receive_pair(output logic [31:0] value_1, output logic [31:0] value_2);
        logic [7:0] byte_value;
        begin
            receive_uart_byte(byte_value); value_1[7:0] = byte_value;
            receive_uart_byte(byte_value); value_1[15:8] = byte_value;
            receive_uart_byte(byte_value); value_1[23:16] = byte_value;
            receive_uart_byte(byte_value); value_1[31:24] = byte_value;
            receive_uart_byte(byte_value); value_2[7:0] = byte_value;
            receive_uart_byte(byte_value); value_2[15:8] = byte_value;
            receive_uart_byte(byte_value); value_2[23:16] = byte_value;
            receive_uart_byte(byte_value); value_2[31:24] = byte_value;
        end
    endtask

    task automatic check_pair(
        input logic [4:0] address_1,
        input logic [31:0] expected_1,
        input logic [4:0] address_2,
        input logic [31:0] expected_2
    );
        logic [31:0] value_1;
        logic [31:0] value_2;
        begin
            send_uart_byte(8'h02);
            send_uart_byte({3'b000, address_1});
            fork
                send_uart_byte({3'b000, address_2});
                receive_pair(value_1, value_2);
            join

            if ((value_1 !== expected_1) || (value_2 !== expected_2)) begin
                errors = errors + 1;
                $display("ERROR READ x%0d=%h x%0d=%h esperado=%h,%h",
                         address_1, value_1, address_2, value_2,
                         expected_1, expected_2);
            end
            if (leds !== expected_1[7:0]) begin
                errors = errors + 1;
                $display("ERROR LEDs esperado=%h obtenido=%h", expected_1[7:0], leds);
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

        check_pair(5'd0, 32'h0, 5'd31, 32'h0);
        write_register(5'd1, 32'h1234_5678);
        write_register(5'd2, 32'hCAFE_BABE);
        write_register(5'd31, 32'hDEAD_BEEF);
        check_pair(5'd1, 32'h1234_5678, 5'd2, 32'hCAFE_BABE);
        check_pair(5'd31, 32'hDEAD_BEEF, 5'd1, 32'h1234_5678);
        write_register(5'd0, 32'hFFFF_FFFF);
        check_pair(5'd0, 32'h0, 5'd31, 32'hDEAD_BEEF);
        write_register(5'd1, 32'hA5A5_5A5A);
        check_pair(5'd1, 32'hA5A5_5A5A, 5'd1, 32'hA5A5_5A5A);

        if (rx_overrun || frame_error) begin
            errors = errors + 1;
            $display("ERROR: flag UART inesperado");
        end

        if (errors == 0)
            $display("RESULTADO: INTEGRACION UART-BANCO RV32 OK");
        else
            $fatal(1, "RESULTADO: %0d ERRORES", errors);

        $finish;
    end

endmodule
