`timescale 1ns / 1ps

module tb_top;

    parameter NB_BITS = 8;
    parameter N_TESTS = 1000;

    // =========================================
    // Entradas del TOP
    // =========================================

    reg                 clk;
    reg [NB_BITS-1:0]   switches;
    reg                 btn_A;
    reg                 btn_B;
    reg                 btn_OP;


    // =========================================
    // Salidas del TOP
    // =========================================

    wire [NB_BITS-1:0]  leds;
    wire                zero;
    wire                carry;
    wire                overflow;


    // =========================================
    // Variables para test aleatorio
    // =========================================

    reg [NB_BITS-1:0] random_A;
    reg [NB_BITS-1:0] random_B;
    reg [5:0]         random_op;

    reg [NB_BITS-1:0] expected_C;
    reg [NB_BITS:0]   expected_aux;

    reg expected_zero;
    reg expected_carry;
    reg expected_overflow;

    integer i;
    integer sel;
    integer errors;


    // =========================================
    // Instancia del TOP
    // =========================================

    top #(
        .NB_BITS(NB_BITS)
    ) DUT (
        .i_clk(clk),
        .i_switches(switches),

        .i_btn_A(btn_A),
        .i_btn_B(btn_B),
        .i_btn_OP(btn_OP),

        .o_leds(leds),
        .o_zero(zero),
        .o_carry(carry),
        .o_overflow(overflow)
    );


    // =========================================
    // Clock de 100 MHz
    // Periodo = 10 ns
    // =========================================

    initial begin
        clk = 1'b0;

        forever #5 clk = ~clk;
    end


    // =========================================
    // TAREA: cargar A
    // =========================================

    task cargar_A;

        input [NB_BITS-1:0] valor;

        begin

            switches = valor;
            btn_A = 1'b1;

            @(posedge clk);
            #1;

            btn_A = 1'b0;

        end

    endtask


    // =========================================
    // TAREA: cargar B
    // =========================================

    task cargar_B;

        input [NB_BITS-1:0] valor;

        begin

            switches = valor;
            btn_B = 1'b1;

            @(posedge clk);
            #1;

            btn_B = 1'b0;

        end

    endtask


    // =========================================
    // TAREA: cargar OP
    // =========================================

    task cargar_OP;

        input [5:0] codigo;

        begin

            // OP utiliza solamente SW[5:0]
            switches = {2'b00, codigo};

            btn_OP = 1'b1;

            @(posedge clk);
            #1;

            btn_OP = 1'b0;

        end

    endtask


    // =========================================
    // TAREA: comprobar resultado
    // =========================================

    task comprobar;

        input [NB_BITS-1:0] esperado_C;
        input esperado_zero;
        input esperado_carry;
        input esperado_overflow;

        begin

            // Dejamos estabilizar lógica combinacional
            #2;

            if (
                (leds     !== esperado_C)        ||
                (zero     !== esperado_zero)     ||
                (carry    !== esperado_carry)    ||
                (overflow !== esperado_overflow)
            ) begin

                errors = errors + 1;

                $display("");
                $display("========================================");
                $display("ERROR");

                $display(
                    "Esperado: C=%b Z=%b CARRY=%b OV=%b",
                    esperado_C,
                    esperado_zero,
                    esperado_carry,
                    esperado_overflow
                );

                $display(
                    "Obtenido: C=%b Z=%b CARRY=%b OV=%b",
                    leds,
                    zero,
                    carry,
                    overflow
                );

                $display("========================================");

            end

        end

    endtask


    // =========================================
    // TEST PRINCIPAL
    // =========================================

    initial begin

        switches = {NB_BITS{1'b0}};

        btn_A  = 1'b0;
        btn_B  = 1'b0;
        btn_OP = 1'b0;

        errors = 0;

        #20;


        // =================================================
        // =================================================
        //
        //          TESTS DIRIGIDOS
        //
        // =================================================
        // =================================================

        $display("");
        $display("========================================");
        $display("INICIO TESTS DIRIGIDOS");
        $display("========================================");


        // =====================================
        // 1 - ADD
        //
        // 10 + 5 = 15
        // =====================================

        $display("TEST ADD");

        cargar_A(8'd10);
        cargar_B(8'd5);
        cargar_OP(6'b100000);

        comprobar(
            8'd15,
            1'b0,
            1'b0,
            1'b0
        );


        // =====================================
        // 2 - SUB
        //
        // 10 - 3 = 7
        // =====================================

        $display("TEST SUB");

        cargar_A(8'd10);
        cargar_B(8'd3);
        cargar_OP(6'b100010);

        comprobar(
            8'd7,
            1'b0,
            1'b1,
            1'b0
        );


        // =====================================
        // 3 - AND
        //
        // 11001100
        // 10101010
        // --------
        // 10001000
        // =====================================

        $display("TEST AND");

        cargar_A(8'b11001100);
        cargar_B(8'b10101010);
        cargar_OP(6'b100100);

        comprobar(
            8'b10001000,
            1'b0,
            1'b0,
            1'b0
        );


        // =====================================
        // 4 - OR
        //
        // 11001100
        // 10101010
        // --------
        // 11101110
        // =====================================

        $display("TEST OR");

        cargar_A(8'b11001100);
        cargar_B(8'b10101010);
        cargar_OP(6'b100101);

        comprobar(
            8'b11101110,
            1'b0,
            1'b0,
            1'b0
        );


        // =====================================
        // 5 - XOR
        //
        // 11001100
        // 10101010
        // --------
        // 01100110
        // =====================================

        $display("TEST XOR");

        cargar_A(8'b11001100);
        cargar_B(8'b10101010);
        cargar_OP(6'b100110);

        comprobar(
            8'b01100110,
            1'b0,
            1'b0,
            1'b0
        );


        // =====================================
        // 6 - SRA
        //
        // 10010000 >>> 2
        // =
        // 11100100
        // =====================================

        $display("TEST SRA");

        cargar_A(8'b10010000);
        cargar_B(8'd2);
        cargar_OP(6'b000011);

        comprobar(
            8'b11100100,
            1'b0,
            1'b0,
            1'b0
        );


        // =====================================
        // 7 - SRL
        //
        // 10010000 >> 2
        // =
        // 00100100
        // =====================================

        $display("TEST SRL");

        cargar_A(8'b10010000);
        cargar_B(8'd2);
        cargar_OP(6'b000010);

        comprobar(
            8'b00100100,
            1'b0,
            1'b0,
            1'b0
        );


        // =====================================
        // 8 - NOR
        //
        // ~(11001100 | 10101010)
        //
        // 00010001
        // =====================================

        $display("TEST NOR");

        cargar_A(8'b11001100);
        cargar_B(8'b10101010);
        cargar_OP(6'b100111);

        comprobar(
            8'b00010001,
            1'b0,
            1'b0,
            1'b0
        );


        // =================================================
        // Tests dirigidos especiales para FLAGS
        // =================================================


        // =====================================
        // ZERO
        //
        // 5 - 5 = 0
        // =====================================

        $display("TEST FLAG ZERO");

        cargar_A(8'd5);
        cargar_B(8'd5);
        cargar_OP(6'b100010);

        comprobar(
            8'd0,
            1'b1,      // ZERO
            1'b1,      // sin borrow
            1'b0
        );


        // =====================================
        // CARRY
        //
        // 255 + 1
        //
        // Resultado = 0
        // Carry = 1
        // =====================================

        $display("TEST FLAG CARRY");

        cargar_A(8'd255);
        cargar_B(8'd1);
        cargar_OP(6'b100000);

        comprobar(
            8'd0,
            1'b1,
            1'b1,      // CARRY
            1'b0
        );


        // =====================================
        // OVERFLOW
        //
        // 127 + 1
        //
        // 01111111
        // +
        // 00000001
        // ----------
        // 10000000
        //
        // Overflow = 1
        // =====================================

        $display("TEST FLAG OVERFLOW");

        cargar_A(8'b01111111);
        cargar_B(8'b00000001);
        cargar_OP(6'b100000);

        comprobar(
            8'b10000000,
            1'b0,
            1'b0,
            1'b1       // OVERFLOW
        );


        $display("");
        $display("========================================");
        $display("FIN TESTS DIRIGIDOS");
        $display("========================================");


        // =================================================
        // =================================================
        //
        //          TESTS ALEATORIOS
        //
        // =================================================
        // =================================================

        $display("");
        $display("========================================");
        $display("INICIO TESTS ALEATORIOS");
        $display("Cantidad: %0d", N_TESTS);
        $display("========================================");


        for (i = 0; i < N_TESTS; i = i + 1) begin

            // =================================
            // Generar A y B aleatorios
            // =================================

            random_A = $random;
            random_B = $random;

            // Selección aleatoria entre 0 y 7
            sel = $random & 32'h7;


            // Valores esperados por defecto
            expected_C        = {NB_BITS{1'b0}};
            expected_aux      = {(NB_BITS+1){1'b0}};
            expected_carry    = 1'b0;
            expected_overflow = 1'b0;


            // =================================
            // Seleccionar operación
            // =================================

            case (sel)


                // =============================
                // ADD
                // =============================

                0: begin

                    random_op = 6'b100000;

                    expected_aux =
                        {1'b0, random_A}
                        +
                        {1'b0, random_B};

                    expected_C =
                        expected_aux[NB_BITS-1:0];

                    expected_carry =
                        expected_aux[NB_BITS];

                    expected_overflow =
                        (~(
                            random_A[NB_BITS-1]
                            ^
                            random_B[NB_BITS-1]
                        ))
                        &
                        (
                            expected_C[NB_BITS-1]
                            ^
                            random_A[NB_BITS-1]
                        );

                end


                // =============================
                // SUB
                // =============================

                1: begin

                    random_op = 6'b100010;

                    expected_aux =
                        {1'b0, random_A}
                        +
                        {1'b0, ~random_B}
                        +
                        1'b1;

                    expected_C =
                        expected_aux[NB_BITS-1:0];

                    expected_carry =
                        expected_aux[NB_BITS];

                    expected_overflow =
                        (
                            random_A[NB_BITS-1]
                            ^
                            random_B[NB_BITS-1]
                        )
                        &
                        (
                            expected_C[NB_BITS-1]
                            ^
                            random_A[NB_BITS-1]
                        );

                end


                // =============================
                // AND
                // =============================

                2: begin

                    random_op = 6'b100100;

                    expected_C =
                        random_A & random_B;

                end


                // =============================
                // OR
                // =============================

                3: begin

                    random_op = 6'b100101;

                    expected_C =
                        random_A | random_B;

                end


                // =============================
                // XOR
                // =============================

                4: begin

                    random_op = 6'b100110;

                    expected_C =
                        random_A ^ random_B;

                end


                // =============================
                // SRA
                // =============================

                5: begin

                    random_op = 6'b000011;

                    // Limitamos B entre 0 y 7
                    random_B = random_B % NB_BITS;

                    expected_C =
                        $signed(random_A) >>> random_B;

                end


                // =============================
                // SRL
                // =============================

                6: begin

                    random_op = 6'b000010;

                    random_B = random_B % NB_BITS;

                    expected_C =
                        random_A >> random_B;

                end


                // =============================
                // NOR
                // =============================

                7: begin

                    random_op = 6'b100111;

                    expected_C =
                        ~(random_A | random_B);

                end


            endcase


            // =================================
            // Calcular ZERO
            // =================================

            expected_zero =
                (expected_C == {NB_BITS{1'b0}});


            // =================================
            // Cargar físicamente los registros
            // =================================

            cargar_A(random_A);

            cargar_B(random_B);

            cargar_OP(random_op);


            // =================================
            // Comprobar salida
            // =================================

            comprobar(
                expected_C,
                expected_zero,
                expected_carry,
                expected_overflow
            );


        end


        // =================================================
        // RESULTADO FINAL
        // =================================================

        $display("");
        $display("========================================");
        $display("RESULTADO FINAL");
        $display("========================================");

        if (errors == 0) begin

            $display("TODOS LOS TESTS PASARON");
            $display("Tests aleatorios realizados: %0d",
                     N_TESTS);

        end
        else begin

            $display("SE ENCONTRARON ERRORES");
            $display("Cantidad de errores: %0d",
                     errors);

        end

        $display("========================================");


        #20;

        $finish;

    end

endmodule