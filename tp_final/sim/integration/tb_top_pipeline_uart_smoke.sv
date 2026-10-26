`timescale 1ns / 1ps

module tb_top_pipeline_uart_smoke;

    localparam integer CLOCK_FREQ_HZ = 16_000_000;
    localparam integer BAUD_RATE     = 1_000_000;
    localparam integer OVERSAMPLE    = 16;
    localparam logic [7:0] CMD_START_PAUSED = 8'h24;
    localparam logic [7:0] CMD_STEP         = 8'h25;
    localparam logic [7:0] CMD_PAUSE        = 8'h26;
    localparam logic [7:0] CMD_RESUME       = 8'h27;
    localparam logic [7:0] CMD_RESET_CORE   = 8'h28;
    localparam logic [7:0] CMD_SNAPSHOT     = 8'h29;

    logic clk, rst, uart_rx;
    wire uart_tx;
    wire [7:0] leds;
    wire rx_overrun, frame_error;
    integer errors;
    integer step_count;
    logic status_active, status_halted, status_paused;
    logic [3:0] status_valid;
    logic [31:0] status_pc, status_cycles, status_retired;
    logic [31:0] previous_cycles;

    top_tp_final #(
        .CLOCK_FREQ_HZ(CLOCK_FREQ_HZ), .BAUD_RATE(BAUD_RATE),
        .USE_CLOCK_MANAGER(0)
    ) DUT (
        .i_clk(clk), .i_rst(rst), .i_uart_rx(uart_rx), .o_uart_tx(uart_tx),
        .o_leds(leds), .o_rx_overrun(rx_overrun), .o_frame_error(frame_error)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic wait_clocks(input integer count);
        integer n;
        begin
            for (n = 0; n < count; n = n + 1) @(posedge clk);
        end
    endtask

    task automatic send_uart_byte(input logic [7:0] value);
        integer n;
        begin
            uart_rx = 1'b0; wait_clocks(OVERSAMPLE);
            for (n = 0; n < 8; n = n + 1) begin
                uart_rx = value[n]; wait_clocks(OVERSAMPLE);
            end
            uart_rx = 1'b1; wait_clocks(OVERSAMPLE);
        end
    endtask

    task automatic receive_uart_byte(output logic [7:0] value);
        integer n;
        begin
            @(negedge uart_tx);
            wait_clocks(OVERSAMPLE / 2);
            for (n = 0; n < 8; n = n + 1) begin
                wait_clocks(OVERSAMPLE); value[n] = uart_tx;
            end
            wait_clocks(OVERSAMPLE);
            if (uart_tx !== 1'b1) begin
                errors = errors + 1;
                $display("ERROR bit de stop UART");
            end
        end
    endtask

    task automatic load_word(input integer index, input logic [31:0] data);
        logic [7:0] status;
        logic [31:0] address;
        begin
            address = index * 4;
            send_uart_byte(8'h10);
            send_uart_byte(address[7:0]); send_uart_byte(address[15:8]);
            send_uart_byte(address[23:16]); send_uart_byte(address[31:24]);
            send_uart_byte(data[7:0]); send_uart_byte(data[15:8]);
            send_uart_byte(data[23:16]);
            fork
                send_uart_byte(data[31:24]);
                receive_uart_byte(status);
            join
            if (status !== 8'h00) begin
                errors = errors + 1;
                $display("ERROR load word %0d status=%02h", index, status);
            end
        end
    endtask

    task automatic load_nops(input integer first_word, input integer count);
        integer n;
        begin
            for (n = 0; n < count; n = n + 1)
                load_word(first_word + n, 32'h0000_0013);
        end
    endtask

    task automatic run_program(input logic [31:0] words);
        logic [7:0] status;
        begin
            send_uart_byte(8'h20);
            send_uart_byte(words[7:0]); send_uart_byte(words[15:8]);
            send_uart_byte(words[23:16]);
            fork
                send_uart_byte(words[31:24]);
                receive_uart_byte(status);
            join
            if (status !== 8'h00) begin
                errors = errors + 1;
                $display("ERROR RUN status=%02h", status);
            end
        end
    endtask

    task automatic start_paused(input logic [31:0] words);
        logic [7:0] status;
        begin
            send_uart_byte(CMD_START_PAUSED);
            send_uart_byte(words[7:0]); send_uart_byte(words[15:8]);
            send_uart_byte(words[23:16]);
            fork
                send_uart_byte(words[31:24]);
                receive_uart_byte(status);
            join
            if (status !== 8'h00) begin
                errors = errors + 1;
                $display("ERROR START_PAUSED status=%02h", status);
            end
        end
    endtask

    task automatic control_command(input logic [7:0] control,
                                   input logic [7:0] expected_status);
        logic [7:0] status;
        begin
            fork
                send_uart_byte(control);
                receive_uart_byte(status);
            join
            if (status !== expected_status) begin
                errors = errors + 1;
                $display("ERROR control=%02h status=%02h esperado=%02h",
                         control, status, expected_status);
            end
        end
    endtask

    task automatic get_status(
        output logic active,
        output logic halted,
        output logic paused,
        output logic [3:0] valid,
        output logic [31:0] reported_pc,
        output logic [31:0] reported_cycles,
        output logic [31:0] reported_retired
    );
        logic [7:0] response [0:15];
        integer n;
        begin
            fork
                send_uart_byte(8'h21);
                begin
                    for (n = 0; n < 16; n = n + 1)
                        receive_uart_byte(response[n]);
                end
            join
            active = response[0][0];
            halted = response[1][0];
            paused = response[1][1];
            valid = response[3][3:0];
            reported_pc = {response[7], response[6], response[5], response[4]};
            reported_cycles = {response[11], response[10], response[9], response[8]};
            reported_retired = {response[15], response[14], response[13], response[12]};
        end
    endtask

    task automatic read_status;
        logic [7:0] response [0:15];
        logic [31:0] reported_cycles;
        logic [31:0] reported_retired;
        integer n;
        begin
            fork
                send_uart_byte(8'h21);
                begin
                    for (n = 0; n < 16; n = n + 1)
                        receive_uart_byte(response[n]);
                end
            join
            reported_cycles = {response[11], response[10], response[9], response[8]};
            reported_retired = {response[15], response[14], response[13], response[12]};
            if ((response[0] !== 8'h00) || (response[1] !== 8'h01) ||
                (response[2] !== 8'h01) || (response[3] !== 8'h00) ||
                (reported_cycles !== 32'd56) ||
                (reported_retired !== 32'd43)) begin
                errors = errors + 1;
                $display("ERROR STATUS run=%02h halt=%02h cause=%02h valid=%02h ciclos=%0d retiradas=%0d",
                         response[0], response[1], response[2], response[3],
                         reported_cycles, reported_retired);
            end
        end
    endtask

    task automatic read_register(input logic [7:0] address,
                                 input logic [31:0] expected);
        logic [7:0] response [0:4];
        logic [31:0] data;
        integer n;
        begin
            send_uart_byte(8'h22);
            fork
                send_uart_byte(address);
                begin
                    for (n = 0; n < 5; n = n + 1)
                        receive_uart_byte(response[n]);
                end
            join
            data = {response[4], response[3], response[2], response[1]};
            if ((response[0] !== 8'h00) || (data !== expected)) begin
                errors = errors + 1;
                $display("ERROR REG x%0d status=%02h data=%08h esperado=%08h",
                         address, response[0], data, expected);
            end
        end
    endtask

    task automatic read_dmem_word(input logic [31:0] address,
                                  input logic [31:0] expected);
        logic [7:0] response [0:4];
        logic [31:0] data;
        integer n;
        begin
            send_uart_byte(8'h23); send_uart_byte(8'h02); send_uart_byte(8'h00);
            send_uart_byte(address[7:0]); send_uart_byte(address[15:8]);
            send_uart_byte(address[23:16]);
            fork
                send_uart_byte(address[31:24]);
                begin
                    for (n = 0; n < 5; n = n + 1)
                        receive_uart_byte(response[n]);
                end
            join
            data = {response[4], response[3], response[2], response[1]};
            if ((response[0] !== 8'h00) || (data !== expected)) begin
                errors = errors + 1;
                $display("ERROR DMEM status=%02h data=%08h esperado=%08h",
                         response[0], data, expected);
            end
        end
    endtask

    task automatic check_snapshot_after_four_steps;
        logic [7:0] status;
        logic [7:0] bytes [0:127];
        logic [31:0] words [0:31];
        integer n;
        begin
            fork
                send_uart_byte(CMD_SNAPSHOT);
                receive_uart_byte(status);
            join
            if (status !== 8'h00) begin
                errors = errors + 1;
                $display("ERROR SNAPSHOT pausado status=%02h", status);
            end
            else begin
                for (n = 0; n < 128; n = n + 1)
                    receive_uart_byte(bytes[n]);
                for (n = 0; n < 32; n = n + 1)
                    words[n] = {bytes[n*4+3], bytes[n*4+2],
                                bytes[n*4+1], bytes[n*4]};

                if ((words[0] !== 32'h534E4150) ||
                    (words[1] !== 32'h00002001) ||
                    (words[2] !== 32'h000000F1) ||
                    (words[3] !== 32'd16) || (words[4] !== 32'd4) ||
                    (words[5] !== 32'd0)) begin
                    errors = errors + 1;
                    $display("ERROR SNAPSHOT global magic=%h version=%h flags=%h pc=%h ciclos=%0d retiradas=%0d",
                             words[0], words[1], words[2], words[3],
                             words[4], words[5]);
                end
                if ((words[6] !== 32'd1) || (words[7] !== 32'd12) ||
                    (words[8] !== 32'h00100073)) begin
                    errors = errors + 1;
                    $display("ERROR SNAPSHOT IFID valid=%h pc=%h instr=%h",
                             words[6], words[7], words[8]);
                end
                if ((words[9] !== 32'd1) || (words[10] !== 32'd8) ||
                    (words[11] !== 32'h00202023) ||
                    (words[12] !== 32'd0) || (words[13] !== 32'd0) ||
                    (words[14] !== 32'd0) || (words[15] !== 32'h00000200) ||
                    (words[16] !== 32'h00000282)) begin
                    errors = errors + 1;
                    $display("ERROR SNAPSHOT IDEX valid=%h pc=%h instr=%h rs1=%h rs2=%h imm=%h regs=%h ctrl=%h",
                             words[9], words[10], words[11], words[12],
                             words[13], words[14], words[15], words[16]);
                end
                if ((words[17] !== 32'd1) || (words[18] !== 32'd4) ||
                    (words[19] !== 32'h00208113) ||
                    (words[20] !== 32'd3) || (words[22] !== 32'd8) ||
                    (words[23] !== 32'h00000211)) begin
                    errors = errors + 1;
                    $display("ERROR SNAPSHOT EXMEM valid=%h pc=%h instr=%h alu=%h store=%h pc4=%h ctrl=%h",
                             words[17], words[18], words[19], words[20],
                             words[21], words[22], words[23]);
                end
                if ((words[24] !== 32'd1) || (words[25] !== 32'd0) ||
                    (words[26] !== 32'h00100093) ||
                    (words[27] !== 32'd1) || (words[29] !== 32'd4) ||
                    (words[30] !== 32'h00000009) ||
                    (words[31] !== 32'd1)) begin
                    errors = errors + 1;
                    $display("ERROR SNAPSHOT MEMWB valid=%h pc=%h instr=%h alu=%h mem=%h pc4=%h ctrl=%h wb=%h",
                             words[24], words[25], words[26], words[27],
                             words[28], words[29], words[30], words[31]);
                end
            end
        end
    endtask

    task automatic check_snapshot_rejected_active;
        logic [7:0] status;
        begin
            fork
                send_uart_byte(CMD_SNAPSHOT);
                receive_uart_byte(status);
            join
            if (status !== 8'h80) begin
                errors = errors + 1;
                $display("ERROR SNAPSHOT activo status=%02h", status);
            end
        end
    endtask

    initial begin
        rst = 1'b1; uart_rx = 1'b1; errors = 0;
        wait_clocks(5); rst = 1'b0; wait_clocks(5);

        load_word(0,  32'h00500093);
        load_word(1,  32'hFF800113);
        load_word(2,  32'h002081B3);
        load_word(3,  32'h40208233);
        load_word(4,  32'h001092B3);
        load_word(5,  32'h00115333);
        load_word(6,  32'h401153B3);
        load_word(7,  32'h0020F433);
        load_word(8,  32'h0020E4B3);
        load_word(9,  32'h0020C533);
        load_word(10, 32'h001125B3);
        load_word(11, 32'h00113633);
        load_word(12, 32'h00F4F693);
        load_word(13, 32'h05546713);
        load_word(14, 32'h0FF74793);
        load_word(15, 32'h00012813);
        load_word(16, 32'h0060B893);
        load_word(17, 32'h00309913);
        load_word(18, 32'h00215993);
        load_word(19, 32'h40215A13);
        load_word(20, 32'hABCDEAB7);
        load_word(21, 32'hF8000B13);
        load_word(22, 32'h01502023);
        load_word(23, 32'h016000A3);
        load_word(24, 32'h00F01123);
        load_word(25, 32'h00100B83);
        load_word(26, 32'h00104C03);
        load_word(27, 32'h00201C83);
        load_word(28, 32'h00205D03);
        load_word(29, 32'h00002D83);
        load_word(30, 32'h016B8663);
        load_word(31, 32'h06300E13);
        load_word(32, 32'h05800E13);
        load_word(33, 32'h00100E13);
        load_word(34, 32'h00209663);
        load_word(35, 32'h04D00E13);
        load_word(36, 32'h04200E13);
        load_word(37, 32'h001E0E13);
        load_word(38, 32'h00208463);
        load_word(39, 32'h001E0E13);
        load_word(40, 32'h00109463);
        load_word(41, 32'h001E0E13);
        load_word(42, 32'h00C00EEF);
        load_word(43, 32'h03700E13);
        load_word(44, 32'h03800E13);
        load_word(45, 32'h001E0E13);
        load_word(46, 32'h0C800F13);
        load_word(47, 32'h000F0FE7);
        load_word(48, 32'h02C00E13);
        load_word(49, 32'h02D00E13);
        load_word(50, 32'h001E0E13);
        load_word(51, 32'h00100073);

        run_program(32'd52);
        wait_clocks(300);
        read_status();
        read_register(8'd3,  32'hFFFFFFFD);
        read_register(8'd7,  32'hFFFFFFFF);
        read_register(8'd15, 32'h000000AA);
        read_register(8'd23, 32'hFFFFFF80);
        read_register(8'd24, 32'h00000080);
        read_register(8'd27, 32'h00AA8000);
        read_register(8'd28, 32'h00000006);
        read_register(8'd29, 32'h000000AC);
        read_register(8'd31, 32'h000000C0);
        read_dmem_word(32'd0, 32'h00AA8000);

        // Inicio pausado y avance de exactamente un ciclo por comando.
        control_command(CMD_RESET_CORE, 8'h00);
        load_word(0, 32'h00100093); // addi x1,x0,1
        load_word(1, 32'h00208113); // addi x2,x1,2
        load_word(2, 32'h00202023); // sw x2,0(x0)
        load_word(3, 32'h00100073); // ebreak
        start_paused(32'd4);
        get_status(status_active, status_halted, status_paused, status_valid,
                   status_pc, status_cycles, status_retired);
        if (status_active || status_halted || !status_paused ||
            (status_cycles != 0) || (status_pc != 0)) begin
            errors = errors + 1;
            $display("ERROR estado inicial pausado active=%0d halt=%0d pause=%0d pc=%h ciclos=%0d",
                     status_active, status_halted, status_paused,
                     status_pc, status_cycles);
        end

        step_count = 0;
        while (!status_halted && (step_count < 20)) begin
            previous_cycles = status_cycles;
            control_command(CMD_STEP, 8'h00);
            get_status(status_active, status_halted, status_paused, status_valid,
                       status_pc, status_cycles, status_retired);
            if (status_cycles != (previous_cycles + 1)) begin
                errors = errors + 1;
                $display("ERROR STEP previo=%0d actual=%0d",
                         previous_cycles, status_cycles);
            end
            step_count = step_count + 1;
            if (step_count == 4)
                check_snapshot_after_four_steps();
        end
        if (!status_halted || (status_cycles != 32'd8) ||
            (status_retired != 32'd3) || (status_valid != 4'b0000)) begin
            errors = errors + 1;
            $display("ERROR final STEP halt=%0d ciclos=%0d retiradas=%0d valid=%b",
                     status_halted, status_cycles, status_retired, status_valid);
        end
        read_register(8'd1, 32'd1);
        read_register(8'd2, 32'd3);
        read_dmem_word(32'd0, 32'd3);
        control_command(CMD_STEP, 8'h80);

        // Programa infinito para comprobar pause, lectura, step y resume.
        control_command(CMD_RESET_CORE, 8'h00);
        read_register(8'd1, 32'd0);
        load_word(0, 32'h00108093); // addi x1,x1,1
        load_word(1, 32'hFFDFF06F); // jal x0,-4
        load_word(2, 32'h00000013); // camino especulativo
        load_word(3, 32'h00000013); // camino especulativo
        run_program(32'd4);
        check_snapshot_rejected_active();
        control_command(CMD_PAUSE, 8'h00);
        get_status(status_active, status_halted, status_paused, status_valid,
                   status_pc, status_cycles, status_retired);
        if (status_active || status_halted || !status_paused) begin
            errors = errors + 1;
            $display("ERROR PAUSE active=%0d halt=%0d pause=%0d",
                     status_active, status_halted, status_paused);
        end
        previous_cycles = status_cycles;
        wait_clocks(200);
        get_status(status_active, status_halted, status_paused, status_valid,
                   status_pc, status_cycles, status_retired);
        if (status_cycles != previous_cycles) begin
            errors = errors + 1;
            $display("ERROR PAUSE no congelo ciclos: %0d -> %0d",
                     previous_cycles, status_cycles);
        end

        control_command(CMD_STEP, 8'h00);
        get_status(status_active, status_halted, status_paused, status_valid,
                   status_pc, status_cycles, status_retired);
        if (status_cycles != (previous_cycles + 1)) begin
            errors = errors + 1;
            $display("ERROR STEP pausado previo=%0d actual=%0d",
                     previous_cycles, status_cycles);
        end
        previous_cycles = status_cycles;
        control_command(CMD_RESUME, 8'h00);
        control_command(CMD_PAUSE, 8'h00);
        get_status(status_active, status_halted, status_paused, status_valid,
                   status_pc, status_cycles, status_retired);
        if (!status_paused || (status_cycles <= previous_cycles)) begin
            errors = errors + 1;
            $display("ERROR RESUME/PAUSE previo=%0d actual=%0d pause=%0d",
                     previous_cycles, status_cycles, status_paused);
        end

        control_command(CMD_RESET_CORE, 8'h00);
        get_status(status_active, status_halted, status_paused, status_valid,
                   status_pc, status_cycles, status_retired);
        if (status_active || status_halted || status_paused ||
            (status_pc != 0) || (status_cycles != 0) ||
            (status_valid != 0)) begin
            errors = errors + 1;
            $display("ERROR RESET active=%0d halt=%0d pause=%0d pc=%h ciclos=%0d valid=%b",
                     status_active, status_halted, status_paused,
                     status_pc, status_cycles, status_valid);
        end
        read_register(8'd1, 32'd0);

        if (rx_overrun || frame_error) begin
            errors = errors + 1;
            $display("ERROR flags UART inesperados");
        end
        if (errors == 0) begin
            $display("RESULTADO: INTEGRACION UART-PIPELINE RV32I OK");
            $display("RESULTADO: CONTROL RUN STEP PAUSE RESET OK");
            $display("RESULTADO: SNAPSHOT COMPLETO DEL PIPELINE OK");
        end
        else
            $fatal(1, "RESULTADO: UART-PIPELINE CON %0d ERRORES", errors);
        $finish;
    end

endmodule
