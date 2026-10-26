`timescale 1ns / 1ps

module tb_top_memory_uart_smoke;

    localparam integer CLOCK_FREQ_HZ = 16_000_000;
    localparam integer BAUD_RATE     = 1_000_000;
    localparam integer OVERSAMPLE    = 16;

    logic clk;
    logic rst;
    logic uart_rx;
    wire uart_tx;
    wire [7:0] leds;
    wire rx_overrun;
    wire frame_error;
    integer errors;

    top_memory_uart_smoke #(
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

    task automatic receive_status(output logic [7:0] status);
        receive_uart_byte(status);
    endtask

    task automatic receive_read_response(
        output logic [7:0] status,
        output logic [31:0] data
    );
        logic [7:0] byte_value;
        begin
            receive_uart_byte(status);
            receive_uart_byte(byte_value); data[7:0] = byte_value;
            receive_uart_byte(byte_value); data[15:8] = byte_value;
            receive_uart_byte(byte_value); data[23:16] = byte_value;
            receive_uart_byte(byte_value); data[31:24] = byte_value;
        end
    endtask

    task automatic check_status(
        input string name,
        input logic [7:0] actual,
        input logic [7:0] expected
    );
        begin
            if (actual !== expected) begin
                errors = errors + 1;
                $display("ERROR %-18s status esperado=%02h obtenido=%02h",
                         name, expected, actual);
            end
        end
    endtask

    task automatic imem_write(
        input string name,
        input logic [31:0] address,
        input logic [31:0] data,
        input logic [7:0] expected_status
    );
        logic [7:0] status;
        begin
            send_uart_byte(8'h10);
            send_uart_byte(address[7:0]);
            send_uart_byte(address[15:8]);
            send_uart_byte(address[23:16]);
            send_uart_byte(address[31:24]);
            send_uart_byte(data[7:0]);
            send_uart_byte(data[15:8]);
            send_uart_byte(data[23:16]);
            fork
                send_uart_byte(data[31:24]);
                receive_status(status);
            join
            check_status(name, status, expected_status);
        end
    endtask

    task automatic imem_read(
        input string name,
        input logic [31:0] address,
        input logic [7:0] expected_status,
        input logic [31:0] expected_data
    );
        logic [7:0] status;
        logic [31:0] data;
        begin
            send_uart_byte(8'h11);
            send_uart_byte(address[7:0]);
            send_uart_byte(address[15:8]);
            send_uart_byte(address[23:16]);
            fork
                send_uart_byte(address[31:24]);
                receive_read_response(status, data);
            join
            check_status(name, status, expected_status);
            if (data !== expected_data) begin
                errors = errors + 1;
                $display("ERROR %-18s data esperado=%08h obtenido=%08h",
                         name, expected_data, data);
            end
            if ((expected_status == 8'h00) && (leds !== expected_data[7:0])) begin
                errors = errors + 1;
                $display("ERROR LED %-15s esperado=%02h obtenido=%02h",
                         name, expected_data[7:0], leds);
            end
        end
    endtask

    task automatic dmem_write(
        input string name,
        input logic [1:0] size,
        input logic [31:0] address,
        input logic [31:0] data,
        input logic [7:0] expected_status
    );
        logic [7:0] status;
        begin
            send_uart_byte(8'h20);
            send_uart_byte({6'b0, size});
            send_uart_byte(address[7:0]);
            send_uart_byte(address[15:8]);
            send_uart_byte(address[23:16]);
            send_uart_byte(address[31:24]);
            send_uart_byte(data[7:0]);
            send_uart_byte(data[15:8]);
            send_uart_byte(data[23:16]);
            fork
                send_uart_byte(data[31:24]);
                receive_status(status);
            join
            check_status(name, status, expected_status);
        end
    endtask

    task automatic dmem_read(
        input string name,
        input logic [1:0] size,
        input logic unsigned_load,
        input logic [31:0] address,
        input logic [7:0] expected_status,
        input logic [31:0] expected_data
    );
        logic [7:0] status;
        logic [31:0] data;
        begin
            send_uart_byte(8'h21);
            send_uart_byte({6'b0, size});
            send_uart_byte({7'b0, unsigned_load});
            send_uart_byte(address[7:0]);
            send_uart_byte(address[15:8]);
            send_uart_byte(address[23:16]);
            fork
                send_uart_byte(address[31:24]);
                receive_read_response(status, data);
            join
            check_status(name, status, expected_status);
            if (data !== expected_data) begin
                errors = errors + 1;
                $display("ERROR %-18s data esperado=%08h obtenido=%08h",
                         name, expected_data, data);
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

        imem_write("IMEM WORD 0", 32'd0, 32'h0010_0093, 8'h00);
        imem_write("IMEM WORD LAST", 32'd4092, 32'h0010_0073, 8'h00);
        imem_read("IMEM READ 0", 32'd0, 8'h00, 32'h0010_0093);
        imem_read("IMEM READ LAST", 32'd4092, 8'h00, 32'h0010_0073);
        imem_write("IMEM MISALIGNED", 32'd2, 32'hDEAD_BEEF, 8'h01);
        imem_read("IMEM RANGE", 32'd4096, 8'h02, 32'd0);

        dmem_write("DMEM SW", 2'd2, 32'h100, 32'h1122_3344, 8'h00);
        dmem_read("DMEM LW", 2'd2, 1'b0, 32'h100, 8'h00, 32'h1122_3344);
        dmem_write("DMEM SB LANE1", 2'd0, 32'h101, 32'h0000_00AA, 8'h00);
        dmem_write("DMEM SB SIGN", 2'd0, 32'h103, 32'h0000_0080, 8'h00);
        dmem_read("DMEM WORD LANES", 2'd2, 1'b0, 32'h100, 8'h00, 32'h8022_AA44);
        dmem_read("DMEM LB", 2'd0, 1'b0, 32'h103, 8'h00, 32'hFFFF_FF80);
        dmem_read("DMEM LBU", 2'd0, 1'b1, 32'h103, 8'h00, 32'h0000_0080);
        dmem_write("DMEM SH", 2'd1, 32'h102, 32'h0000_BEEF, 8'h00);
        dmem_read("DMEM LH", 2'd1, 1'b0, 32'h102, 8'h00, 32'hFFFF_BEEF);
        dmem_read("DMEM LHU", 2'd1, 1'b1, 32'h102, 8'h00, 32'h0000_BEEF);
        dmem_write("DMEM HALF ALIGN", 2'd1, 32'h101, 32'h1234, 8'h01);
        dmem_read("DMEM WORD ALIGN", 2'd2, 1'b0, 32'h102, 8'h01, 32'd0);
        dmem_read("DMEM RANGE", 2'd0, 1'b0, 32'd4096, 8'h02, 32'd0);

        if (rx_overrun || frame_error) begin
            errors = errors + 1;
            $display("ERROR: flag UART inesperado");
        end

        if (errors == 0)
            $display("RESULTADO: INTEGRACION UART-MEMORIAS RV32 OK");
        else
            $fatal(1, "RESULTADO: %0d ERRORES", errors);

        $finish;
    end

endmodule
