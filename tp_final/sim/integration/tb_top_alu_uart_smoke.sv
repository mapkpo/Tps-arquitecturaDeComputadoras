`timescale 1ns / 1ps

module tb_top_alu_uart_smoke;

    localparam integer CLOCK_FREQ_HZ = 16_000_000;
    localparam integer BAUD_RATE     = 1_000_000;
    localparam integer OVERSAMPLE    = 16;

    logic       clk;
    logic       rst;
    logic       uart_rx;
    wire        uart_tx;
    wire [7:0]  leds;
    wire        rx_overrun;
    wire        frame_error;
    integer     errors;

    top_alu_uart_smoke #(
        .CLOCK_FREQ_HZ(CLOCK_FREQ_HZ),
        .BAUD_RATE(BAUD_RATE)
    ) DUT (
        .i_clk(clk),
        .i_rst(rst),
        .i_uart_rx(uart_rx),
        .o_uart_tx(uart_tx),
        .o_leds(leds),
        .o_rx_overrun(rx_overrun),
        .o_frame_error(frame_error)
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

    task automatic receive_result(output logic [31:0] value);
        logic [7:0] byte_value;
        begin
            receive_uart_byte(byte_value);
            value[7:0] = byte_value;
            receive_uart_byte(byte_value);
            value[15:8] = byte_value;
            receive_uart_byte(byte_value);
            value[23:16] = byte_value;
            receive_uart_byte(byte_value);
            value[31:24] = byte_value;
        end
    endtask

    task automatic test_operation(
        input logic [3:0]  operation,
        input logic [31:0] a,
        input logic [31:0] b,
        input logic [31:0] expected
    );
        logic [31:0] received;
        begin
            send_uart_byte(a[7:0]);
            send_uart_byte(a[15:8]);
            send_uart_byte(a[23:16]);
            send_uart_byte(a[31:24]);
            send_uart_byte(b[7:0]);
            send_uart_byte(b[15:8]);
            send_uart_byte(b[23:16]);
            send_uart_byte(b[31:24]);

            fork
                send_uart_byte({4'h0, operation});
                receive_result(received);
            join

            if (received !== expected) begin
                errors = errors + 1;
                $display("ERROR op=%h A=%h B=%h esperado=%h recibido=%h",
                         operation, a, b, expected, received);
            end
            if (leds !== expected[7:0]) begin
                errors = errors + 1;
                $display("ERROR LEDs esperado=%h recibido=%h", expected[7:0], leds);
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

        test_operation(4'h0, 32'd10,        32'd5,         32'd15);
        test_operation(4'h1, 32'd3,         32'd10,        32'hFFFF_FFF9);
        test_operation(4'h4, 32'h8000_0000, 32'd1,         32'hC000_0000);
        test_operation(4'h7, 32'hAA55_F00F, 32'h0FF0_55AA, 32'hA5A5_A5A5);
        test_operation(4'h8, 32'hFFFF_FFFF, 32'd1,         32'h0000_0001);
        test_operation(4'h9, 32'hFFFF_FFFF, 32'd1,         32'h0000_0000);

        if (rx_overrun || frame_error) begin
            errors = errors + 1;
            $display("ERROR: flag UART inesperado");
        end

        if (errors == 0)
            $display("RESULTADO: INTEGRACION UART-ALU RV32 OK");
        else
            $fatal(1, "RESULTADO: %0d ERRORES", errors);

        $finish;
    end

endmodule
