`timescale 1ns / 1ps

module tb_uart;

    localparam integer DATA_BITS     = 8;
    localparam integer OVERSAMPLE    = 16;
    localparam integer CLOCK_FREQ_HZ = 16_000_000;
    localparam integer BAUD_RATE     = 1_000_000;
    localparam integer N_RANDOM      = 32;

    reg clk;
    reg rst;
    reg rx;
    wire tx;

    wire [DATA_BITS-1:0] r_data;
    reg rd;
    wire rx_empty;

    reg [DATA_BITS-1:0] w_data;
    reg wr;
    wire tx_full;

    wire rx_overrun;
    wire frame_error;

    integer errors;
    integer i;
    reg [7:0] random_byte;

    uart #(
        .CLOCK_FREQ_HZ(CLOCK_FREQ_HZ),
        .BAUD_RATE(BAUD_RATE),
        .DATA_BITS(DATA_BITS),
        .STOP_BITS(1),
        .OVERSAMPLE(OVERSAMPLE)
    ) DUT (
        .i_clk(clk),
        .i_rst(rst),
        .i_rx(rx),
        .o_tx(tx),
        .o_r_data(r_data),
        .i_rd(rd),
        .o_rx_empty(rx_empty),
        .i_w_data(w_data),
        .i_wr(wr),
        .o_tx_full(tx_full),
        .o_rx_overrun(rx_overrun),
        .o_frame_error(frame_error)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic wait_clocks;
        input integer count;
        integer n;
        begin
            for (n = 0; n < count; n = n + 1)
                @(posedge clk);
        end
    endtask

    task automatic send_rx_byte;
        input [7:0] value;
        integer n;
        begin
            rx = 1'b0;
            wait_clocks(OVERSAMPLE);

            for (n = 0; n < DATA_BITS; n = n + 1) begin
                rx = value[n];
                wait_clocks(OVERSAMPLE);
            end

            rx = 1'b1;
            wait_clocks(OVERSAMPLE);
        end
    endtask

    task automatic check_received_byte;
        input [7:0] expected;
        integer timeout;
        begin
            timeout = 0;
            while (rx_empty && timeout < 4 * OVERSAMPLE) begin
                @(posedge clk);
                timeout = timeout + 1;
            end

            if (rx_empty) begin
                errors = errors + 1;
                $display("ERROR RX: timeout esperando 0x%02h", expected);
            end
            else if (r_data !== expected) begin
                errors = errors + 1;
                $display("ERROR RX: esperado=0x%02h obtenido=0x%02h",
                         expected, r_data);
            end

            rd = 1'b1;
            @(posedge clk);
            #1 rd = 1'b0;
        end
    endtask

    task automatic write_tx_byte;
        input [7:0] value;
        begin
            while (tx_full)
                @(posedge clk);
            w_data = value;
            wr = 1'b1;
            @(posedge clk);
            #1 wr = 1'b0;
        end
    endtask

    task automatic check_tx_byte;
        input [7:0] expected;
        integer n;
        begin
            @(negedge tx);
            wait_clocks(OVERSAMPLE / 2);

            if (tx !== 1'b0) begin
                errors = errors + 1;
                $display("ERROR TX: bit de start invalido");
            end

            for (n = 0; n < DATA_BITS; n = n + 1) begin
                wait_clocks(OVERSAMPLE);
                if (tx !== expected[n]) begin
                    errors = errors + 1;
                    $display("ERROR TX: dato=0x%02h bit=%0d esperado=%b obtenido=%b",
                             expected, n, expected[n], tx);
                end
            end

            wait_clocks(OVERSAMPLE);
            if (tx !== 1'b1) begin
                errors = errors + 1;
                $display("ERROR TX: bit de stop invalido");
            end
        end
    endtask

    initial begin
        rst    = 1'b1;
        rx     = 1'b1;
        rd     = 1'b0;
        w_data = 8'b0;
        wr     = 1'b0;
        errors = 0;

        wait_clocks(5);
        rst = 1'b0;
        wait_clocks(5);

        $display("INICIO: tests dirigidos RX");
        send_rx_byte(8'h00);
        check_received_byte(8'h00);
        send_rx_byte(8'hA5);
        check_received_byte(8'hA5);
        send_rx_byte(8'hFF);
        check_received_byte(8'hFF);

        $display("INICIO: tests dirigidos TX");
        fork
            begin
                write_tx_byte(8'h00);
                check_tx_byte(8'h00);
            end
        join
        fork
            begin
                write_tx_byte(8'hA5);
                check_tx_byte(8'hA5);
            end
        join
        fork
            begin
                write_tx_byte(8'hFF);
                check_tx_byte(8'hFF);
            end
        join

        $display("INICIO: tests aleatorios RX (%0d bytes)", N_RANDOM);
        for (i = 0; i < N_RANDOM; i = i + 1) begin
            random_byte = $random;
            send_rx_byte(random_byte);
            check_received_byte(random_byte);
        end

        $display("INICIO: tests aleatorios TX (%0d bytes)", N_RANDOM);
        for (i = 0; i < N_RANDOM; i = i + 1) begin
            random_byte = $random;
            fork
                begin
                    write_tx_byte(random_byte);
                    check_tx_byte(random_byte);
                end
            join
        end

        $display("INICIO: test full-duplex");
        fork
            begin
                send_rx_byte(8'h3C);
            end
            begin
                write_tx_byte(8'hC3);
                check_tx_byte(8'hC3);
            end
        join
        check_received_byte(8'h3C);

        if (errors == 0)
            $display("RESULTADO: TODOS LOS TESTS PASARON");
        else
            $display("RESULTADO: %0d ERRORES", errors);

        #100;
        $finish;
    end

endmodule
