`timescale 1ns / 1ps

// Primer core integrado: pipeline RV32I de cinco etapas.
// Los riesgos de datos deben evitarse con NOPs en esta etapa incremental.
module rv32_pipeline_core (
    input  logic        i_clk,
    input  logic        i_rst,
    input  logic        i_start,
    input  logic        i_enable,
    input  logic [31:0] i_program_words,

    output logic        o_imem_read_enable,
    output logic [31:0] o_imem_read_addr,
    input  logic [31:0] i_imem_read_data,
    input  logic        i_imem_read_misaligned,
    input  logic        i_imem_read_out_of_range,

    output logic        o_dmem_read_enable,
    output logic [31:0] o_dmem_read_addr,
    output logic [1:0]  o_dmem_read_size,
    output logic        o_dmem_read_unsigned,
    input  logic [31:0] i_dmem_read_data,
    input  logic        i_dmem_read_misaligned,
    input  logic        i_dmem_read_out_of_range,

    output logic        o_dmem_write_enable,
    output logic [31:0] o_dmem_write_addr,
    output logic [1:0]  o_dmem_write_size,
    output logic [31:0] o_dmem_write_data,
    input  logic        i_dmem_write_misaligned,
    input  logic        i_dmem_write_out_of_range,

    input  logic [4:0]  i_debug_reg_addr,
    output logic [31:0] o_debug_reg_data,
    input  logic [4:0]  i_debug_snapshot_word_addr,
    output logic [31:0] o_debug_snapshot_word_data,
    output logic        o_running,
    output logic        o_halted,
    output logic [3:0]  o_stop_cause,
    output logic [31:0] o_pc,
    output logic [31:0] o_cycle_count,
    output logic [31:0] o_retired_count,
    output logic [3:0]  o_pipeline_valid
);

    localparam logic [1:0] BR_NONE   = 2'd0;
    localparam logic [1:0] BR_EQ     = 2'd1;
    localparam logic [1:0] BR_NE     = 2'd2;
    localparam logic [1:0] JUMP_NONE = 2'd0;
    localparam logic [1:0] JUMP_JAL  = 2'd1;
    localparam logic [1:0] JUMP_JALR = 2'd2;
    localparam logic [1:0] WB_ALU    = 2'd0;
    localparam logic [1:0] WB_MEM    = 2'd1;
    localparam logic [1:0] WB_PC4    = 2'd2;

    localparam logic [3:0] STOP_NONE       = 4'd0;
    localparam logic [3:0] STOP_HALT       = 4'd1;
    localparam logic [3:0] STOP_ILLEGAL    = 4'd2;
    localparam logic [3:0] STOP_PC_RANGE   = 4'd3;
    localparam logic [3:0] STOP_IMEM_FAULT = 4'd4;
    localparam logic [3:0] STOP_DMEM_ALIGN = 4'd5;
    localparam logic [3:0] STOP_DMEM_RANGE = 4'd6;

    logic [31:0] pc;
    logic        fetch_stopped;
    logic [3:0]  pending_cause;

    logic        ifid_valid;
    logic [31:0] ifid_pc;
    logic [31:0] ifid_instruction;

    logic        idex_valid;
    logic [31:0] idex_pc;
    logic [31:0] idex_instruction;
    logic [31:0] idex_rs1_data;
    logic [31:0] idex_rs2_data;
    logic [4:0]  idex_rs1;
    logic [4:0]  idex_rs2;
    logic [31:0] idex_immediate;
    logic [4:0]  idex_rd;
    logic        idex_reg_write;
    logic        idex_alu_src_imm;
    logic [3:0]  idex_alu_op;
    logic        idex_mem_read;
    logic        idex_mem_write;
    logic [1:0]  idex_mem_size;
    logic        idex_mem_unsigned;
    logic [1:0]  idex_branch;
    logic [1:0]  idex_jump;
    logic [1:0]  idex_wb_sel;

    logic        exmem_valid;
    logic [31:0] exmem_pc;
    logic [31:0] exmem_instruction;
    logic [31:0] exmem_alu_result;
    logic [31:0] exmem_store_data;
    logic [31:0] exmem_pc4;
    logic [4:0]  exmem_rd;
    logic        exmem_reg_write;
    logic        exmem_mem_read;
    logic        exmem_mem_write;
    logic [1:0]  exmem_mem_size;
    logic        exmem_mem_unsigned;
    logic [1:0]  exmem_wb_sel;

    logic        memwb_valid;
    logic [31:0] memwb_pc;
    logic [31:0] memwb_instruction;
    logic [31:0] memwb_alu_result;
    logic [31:0] memwb_mem_data;
    logic [31:0] memwb_pc4;
    logic [4:0]  memwb_rd;
    logic        memwb_reg_write;
    logic [1:0]  memwb_wb_sel;

    logic [4:0]  dec_rs1;
    logic [4:0]  dec_rs2;
    logic [4:0]  dec_rd;
    logic        dec_legal;
    logic        dec_halt;
    logic        dec_uses_rs1;
    logic        dec_uses_rs2;
    logic        dec_reg_write;
    logic        dec_alu_src_imm;
    logic [3:0]  dec_alu_op;
    logic [2:0]  dec_imm_type;
    logic        dec_mem_read;
    logic        dec_mem_write;
    logic [1:0]  dec_mem_size;
    logic        dec_mem_unsigned;
    logic [1:0]  dec_branch;
    logic [1:0]  dec_jump;
    logic [1:0]  dec_wb_sel;
    logic [31:0] dec_immediate;
    logic [31:0] rf_rs1_data;
    logic [31:0] rf_rs2_data;
    logic [31:0] dec_rs1_data;
    logic [31:0] dec_rs2_data;
    logic        rf_write_enable;
    logic [31:0] wb_data;

    logic [31:0] ex_rs1_forwarded;
    logic [31:0] ex_rs2_forwarded;
    logic [31:0] exmem_forward_data;
    logic [31:0] alu_operand_b;
    logic [31:0] alu_result;
    logic        alu_zero;
    logic        ex_branch_taken;
    logic        ex_redirect;
    logic [31:0] ex_redirect_target;
    logic [31:0] program_bytes;
    logic        fetch_address_valid;
    logic        dmem_access_fault;
    logic [3:0]  dmem_fault_cause;
    logic        load_use_hazard;

    assign program_bytes = i_program_words << 2;
    assign fetch_address_valid = (pc < program_bytes);

    assign o_imem_read_enable = o_running && i_enable &&
                                !fetch_stopped && fetch_address_valid;
    assign o_imem_read_addr = pc;

    assign o_dmem_read_enable = o_running && i_enable && exmem_valid &&
                                exmem_mem_read;
    assign o_dmem_read_addr = exmem_alu_result;
    assign o_dmem_read_size = exmem_mem_size;
    assign o_dmem_read_unsigned = exmem_mem_unsigned;

    assign o_dmem_write_enable = o_running && i_enable && exmem_valid &&
                                 exmem_mem_write;
    assign o_dmem_write_addr = exmem_alu_result;
    assign o_dmem_write_size = exmem_mem_size;
    assign o_dmem_write_data = exmem_store_data;

    assign o_pc = pc;
    assign o_pipeline_valid = {memwb_valid, exmem_valid, idex_valid, ifid_valid};

    // Ventana de observación de 32 palabras para la Debug Unit. El controlador
    // sólo permite leerla con el pipeline pausado o detenido, por lo que todas
    // las palabras pertenecen al mismo ciclo aunque UART las transmita de a una.
    always_comb begin
        case (i_debug_snapshot_word_addr)
            5'd0:  o_debug_snapshot_word_data = 32'h534E_4150; // "SNAP"
            5'd1:  o_debug_snapshot_word_data = 32'h0000_2001; // 32 words, v1
            5'd2:  o_debug_snapshot_word_data = {
                19'd0, fetch_stopped, o_stop_cause, o_pipeline_valid,
                1'b0, i_enable, o_halted, o_running
            };
            5'd3:  o_debug_snapshot_word_data = pc;
            5'd4:  o_debug_snapshot_word_data = o_cycle_count;
            5'd5:  o_debug_snapshot_word_data = o_retired_count;

            5'd6:  o_debug_snapshot_word_data = {31'd0, ifid_valid};
            5'd7:  o_debug_snapshot_word_data = ifid_pc;
            5'd8:  o_debug_snapshot_word_data = ifid_instruction;

            5'd9:  o_debug_snapshot_word_data = {31'd0, idex_valid};
            5'd10: o_debug_snapshot_word_data = idex_pc;
            5'd11: o_debug_snapshot_word_data = idex_instruction;
            5'd12: o_debug_snapshot_word_data = idex_rs1_data;
            5'd13: o_debug_snapshot_word_data = idex_rs2_data;
            5'd14: o_debug_snapshot_word_data = idex_immediate;
            5'd15: o_debug_snapshot_word_data = {
                11'd0, idex_rd, 3'd0, idex_rs2, 3'd0, idex_rs1
            };
            5'd16: o_debug_snapshot_word_data = {
                15'd0, idex_wb_sel, idex_jump, idex_branch,
                idex_mem_unsigned, idex_mem_size, idex_mem_write,
                idex_mem_read, idex_alu_op, idex_alu_src_imm,
                idex_reg_write
            };

            5'd17: o_debug_snapshot_word_data = {31'd0, exmem_valid};
            5'd18: o_debug_snapshot_word_data = exmem_pc;
            5'd19: o_debug_snapshot_word_data = exmem_instruction;
            5'd20: o_debug_snapshot_word_data = exmem_alu_result;
            5'd21: o_debug_snapshot_word_data = exmem_store_data;
            5'd22: o_debug_snapshot_word_data = exmem_pc4;
            5'd23: o_debug_snapshot_word_data = {
                19'd0, exmem_rd, exmem_wb_sel, exmem_mem_unsigned,
                exmem_mem_size, exmem_mem_write, exmem_mem_read,
                exmem_reg_write
            };

            5'd24: o_debug_snapshot_word_data = {31'd0, memwb_valid};
            5'd25: o_debug_snapshot_word_data = memwb_pc;
            5'd26: o_debug_snapshot_word_data = memwb_instruction;
            5'd27: o_debug_snapshot_word_data = memwb_alu_result;
            5'd28: o_debug_snapshot_word_data = memwb_mem_data;
            5'd29: o_debug_snapshot_word_data = memwb_pc4;
            5'd30: o_debug_snapshot_word_data = {
                24'd0, memwb_rd, memwb_wb_sel, memwb_reg_write
            };
            5'd31: o_debug_snapshot_word_data = wb_data;
            default: o_debug_snapshot_word_data = 32'd0;
        endcase
    end

    always_comb begin
        case (memwb_wb_sel)
            WB_MEM:  wb_data = memwb_mem_data;
            WB_PC4:  wb_data = memwb_pc4;
            default: wb_data = memwb_alu_result;
        endcase
    end

    assign rf_write_enable = o_running && i_enable && memwb_valid &&
                             memwb_reg_write;

    // Bypass WB->ID para la lectura que coincide con la escritura del mismo
    // flanco positivo. Evita depender del valor previo registrado en negedge.
    always_comb begin
        dec_rs1_data = dec_uses_rs1 ? rf_rs1_data : 32'h0000_0000;
        dec_rs2_data = dec_uses_rs2 ? rf_rs2_data : 32'h0000_0000;
        if (memwb_valid && memwb_reg_write && (memwb_rd != 5'd0)) begin
            if (dec_uses_rs1 && (dec_rs1 == memwb_rd))
                dec_rs1_data = wb_data;
            if (dec_uses_rs2 && (dec_rs2 == memwb_rd))
                dec_rs2_data = wb_data;
        end
    end

    rv32_register_file REGISTER_FILE (
        .i_clk(i_clk),
        .i_rst(i_rst || i_start),
        .i_write_enable(rf_write_enable),
        .i_write_addr(memwb_rd),
        .i_write_data(wb_data),
        .i_read_addr_1(dec_rs1),
        .i_read_addr_2(dec_rs2),
        .o_read_data_1(rf_rs1_data),
        .o_read_data_2(rf_rs2_data),
        .i_debug_read_addr(i_debug_reg_addr),
        .o_debug_read_data(o_debug_reg_data)
    );

    rv32_decoder DECODER (
        .i_instruction(ifid_instruction),
        .o_rs1(dec_rs1), .o_rs2(dec_rs2), .o_rd(dec_rd),
        .o_legal(dec_legal), .o_halt(dec_halt),
        .o_uses_rs1(dec_uses_rs1), .o_uses_rs2(dec_uses_rs2),
        .o_reg_write(dec_reg_write), .o_alu_src_imm(dec_alu_src_imm),
        .o_alu_op(dec_alu_op), .o_imm_type(dec_imm_type),
        .o_mem_read(dec_mem_read), .o_mem_write(dec_mem_write),
        .o_mem_size(dec_mem_size), .o_mem_unsigned(dec_mem_unsigned),
        .o_branch(dec_branch), .o_jump(dec_jump), .o_wb_sel(dec_wb_sel)
    );

    rv32_immediate_generator IMMEDIATE_GENERATOR (
        .i_instruction(ifid_instruction),
        .i_imm_type(dec_imm_type),
        .o_immediate(dec_immediate)
    );

    always_comb begin
        case (exmem_wb_sel)
            WB_PC4:  exmem_forward_data = exmem_pc4;
            default: exmem_forward_data = exmem_alu_result;
        endcase

        ex_rs1_forwarded = idex_rs1_data;
        ex_rs2_forwarded = idex_rs2_data;

        // MEM/WB tiene menor prioridad que EX/MEM.
        if (memwb_valid && memwb_reg_write && (memwb_rd != 5'd0) &&
            (memwb_rd == idex_rs1))
            ex_rs1_forwarded = wb_data;
        if (memwb_valid && memwb_reg_write && (memwb_rd != 5'd0) &&
            (memwb_rd == idex_rs2))
            ex_rs2_forwarded = wb_data;

        // Un load no puede reenviarse desde EX/MEM: se resuelve con un stall.
        if (exmem_valid && exmem_reg_write && (exmem_rd != 5'd0) &&
            (exmem_wb_sel != WB_MEM) && (exmem_rd == idex_rs1))
            ex_rs1_forwarded = exmem_forward_data;
        if (exmem_valid && exmem_reg_write && (exmem_rd != 5'd0) &&
            (exmem_wb_sel != WB_MEM) && (exmem_rd == idex_rs2))
            ex_rs2_forwarded = exmem_forward_data;
    end

    assign alu_operand_b = idex_alu_src_imm ? idex_immediate
                                             : ex_rs2_forwarded;

    rv32_alu ALU (
        .i_a(ex_rs1_forwarded),
        .i_b(alu_operand_b),
        .i_op(idex_alu_op),
        .o_result(alu_result),
        .o_zero(alu_zero)
    );

    always_comb begin
        case (idex_branch)
            BR_EQ:   ex_branch_taken = (ex_rs1_forwarded == ex_rs2_forwarded);
            BR_NE:   ex_branch_taken = (ex_rs1_forwarded != ex_rs2_forwarded);
            default: ex_branch_taken = 1'b0;
        endcase

        ex_redirect = idex_valid &&
                      ((idex_jump != JUMP_NONE) || ex_branch_taken);
        if (idex_jump == JUMP_JALR)
            ex_redirect_target = (ex_rs1_forwarded + idex_immediate) &
                                 32'hFFFF_FFFE;
        else
            ex_redirect_target = idex_pc + idex_immediate;
    end

    always_comb begin
        load_use_hazard = idex_valid && idex_mem_read && (idex_rd != 5'd0) &&
                          ifid_valid &&
                          ((dec_uses_rs1 && (dec_rs1 == idex_rd)) ||
                           (dec_uses_rs2 && (dec_rs2 == idex_rd)));
    end

    always_comb begin
        dmem_access_fault = 1'b0;
        dmem_fault_cause = STOP_NONE;
        if (exmem_valid && exmem_mem_read) begin
            if (i_dmem_read_out_of_range) begin
                dmem_access_fault = 1'b1;
                dmem_fault_cause = STOP_DMEM_RANGE;
            end
            else if (i_dmem_read_misaligned) begin
                dmem_access_fault = 1'b1;
                dmem_fault_cause = STOP_DMEM_ALIGN;
            end
        end
        else if (exmem_valid && exmem_mem_write) begin
            if (i_dmem_write_out_of_range) begin
                dmem_access_fault = 1'b1;
                dmem_fault_cause = STOP_DMEM_RANGE;
            end
            else if (i_dmem_write_misaligned) begin
                dmem_access_fault = 1'b1;
                dmem_fault_cause = STOP_DMEM_ALIGN;
            end
        end
    end

    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            pc                  <= 32'h0000_0000;
            o_running           <= 1'b0;
            o_halted            <= 1'b0;
            o_stop_cause        <= STOP_NONE;
            o_cycle_count       <= 32'h0000_0000;
            o_retired_count     <= 32'h0000_0000;
            fetch_stopped       <= 1'b1;
            pending_cause       <= STOP_NONE;
            ifid_valid          <= 1'b0;
            ifid_pc             <= 32'h0000_0000;
            ifid_instruction    <= 32'h0000_0013;
            idex_valid          <= 1'b0;
            idex_pc             <= 32'h0000_0000;
            idex_instruction    <= 32'h0000_0013;
            idex_rs1_data       <= 32'h0000_0000;
            idex_rs2_data       <= 32'h0000_0000;
            idex_rs1            <= 5'd0;
            idex_rs2            <= 5'd0;
            idex_immediate      <= 32'h0000_0000;
            idex_rd             <= 5'd0;
            idex_reg_write      <= 1'b0;
            idex_alu_src_imm    <= 1'b0;
            idex_alu_op         <= 4'd0;
            idex_mem_read       <= 1'b0;
            idex_mem_write      <= 1'b0;
            idex_mem_size       <= 2'd2;
            idex_mem_unsigned   <= 1'b0;
            idex_branch         <= BR_NONE;
            idex_jump           <= JUMP_NONE;
            idex_wb_sel         <= WB_ALU;
            exmem_valid         <= 1'b0;
            exmem_pc            <= 32'h0000_0000;
            exmem_instruction   <= 32'h0000_0013;
            exmem_alu_result    <= 32'h0000_0000;
            exmem_store_data    <= 32'h0000_0000;
            exmem_pc4           <= 32'h0000_0000;
            exmem_rd            <= 5'd0;
            exmem_reg_write     <= 1'b0;
            exmem_mem_read      <= 1'b0;
            exmem_mem_write     <= 1'b0;
            exmem_mem_size      <= 2'd2;
            exmem_mem_unsigned  <= 1'b0;
            exmem_wb_sel        <= WB_ALU;
            memwb_valid         <= 1'b0;
            memwb_pc            <= 32'h0000_0000;
            memwb_instruction   <= 32'h0000_0013;
            memwb_alu_result    <= 32'h0000_0000;
            memwb_mem_data      <= 32'h0000_0000;
            memwb_pc4           <= 32'h0000_0000;
            memwb_rd            <= 5'd0;
            memwb_reg_write     <= 1'b0;
            memwb_wb_sel        <= WB_ALU;
        end
        else if (i_start) begin
            pc                  <= 32'h0000_0000;
            o_running           <= 1'b1;
            o_halted            <= 1'b0;
            o_stop_cause        <= STOP_NONE;
            o_cycle_count       <= 32'h0000_0000;
            o_retired_count     <= 32'h0000_0000;
            fetch_stopped       <= 1'b0;
            pending_cause       <= STOP_NONE;
            ifid_valid          <= 1'b0;
            idex_valid          <= 1'b0;
            exmem_valid         <= 1'b0;
            memwb_valid         <= 1'b0;
        end
        else if (o_running && i_enable) begin
            o_cycle_count <= o_cycle_count + 32'd1;
            if (memwb_valid)
                o_retired_count <= o_retired_count + 32'd1;

            // Avance normal de las etapas más antiguas.
            memwb_valid      <= exmem_valid;
            memwb_pc         <= exmem_pc;
            memwb_instruction <= exmem_instruction;
            memwb_alu_result <= exmem_alu_result;
            memwb_mem_data   <= i_dmem_read_data;
            memwb_pc4        <= exmem_pc4;
            memwb_rd         <= exmem_rd;
            memwb_reg_write  <= exmem_reg_write;
            memwb_wb_sel     <= exmem_wb_sel;

            exmem_valid        <= idex_valid;
            exmem_pc           <= idex_pc;
            exmem_instruction  <= idex_instruction;
            exmem_alu_result   <= alu_result;
            exmem_store_data   <= ex_rs2_forwarded;
            exmem_pc4          <= idex_pc + 32'd4;
            exmem_rd           <= idex_rd;
            exmem_reg_write    <= idex_reg_write;
            exmem_mem_read     <= idex_mem_read;
            exmem_mem_write    <= idex_mem_write;
            exmem_mem_size     <= idex_mem_size;
            exmem_mem_unsigned <= idex_mem_unsigned;
            exmem_wb_sel       <= idex_wb_sel;

            idex_valid        <= ifid_valid && dec_legal && !dec_halt;
            idex_pc           <= ifid_pc;
            idex_instruction  <= ifid_instruction;
            idex_rs1_data     <= dec_rs1_data;
            idex_rs2_data     <= dec_rs2_data;
            idex_rs1          <= dec_rs1;
            idex_rs2          <= dec_rs2;
            idex_immediate    <= dec_immediate;
            idex_rd           <= dec_rd;
            idex_reg_write    <= dec_reg_write;
            idex_alu_src_imm  <= dec_alu_src_imm;
            idex_alu_op       <= dec_alu_op;
            idex_mem_read     <= dec_mem_read;
            idex_mem_write    <= dec_mem_write;
            idex_mem_size     <= dec_mem_size;
            idex_mem_unsigned <= dec_mem_unsigned;
            idex_branch       <= dec_branch;
            idex_jump         <= dec_jump;
            idex_wb_sel       <= dec_wb_sel;

            ifid_valid       <= !fetch_stopped && fetch_address_valid &&
                                !i_imem_read_misaligned &&
                                !i_imem_read_out_of_range;
            ifid_pc          <= pc;
            ifid_instruction <= i_imem_read_data;
            if (!fetch_stopped && fetch_address_valid)
                pc <= pc + 32'd4;

            // Un fault de MEM anula la instrucción defectuosa y las jóvenes.
            if (dmem_access_fault) begin
                memwb_valid   <= 1'b0;
                exmem_valid   <= 1'b0;
                idex_valid    <= 1'b0;
                ifid_valid    <= 1'b0;
                fetch_stopped <= 1'b1;
                pending_cause <= dmem_fault_cause;
            end
            // Saltos y branches se resuelven en EX y limpian las dos jóvenes.
            else if (ex_redirect) begin
                pc            <= ex_redirect_target;
                idex_valid    <= 1'b0;
                ifid_valid    <= 1'b0;
            end
            // HALT e instrucción ilegal no ingresan a EX; las antiguas drenan.
            else if (ifid_valid && dec_halt) begin
                idex_valid    <= 1'b0;
                ifid_valid    <= 1'b0;
                fetch_stopped <= 1'b1;
                pending_cause <= STOP_HALT;
            end
            else if (ifid_valid && !dec_legal) begin
                idex_valid    <= 1'b0;
                ifid_valid    <= 1'b0;
                fetch_stopped <= 1'b1;
                pending_cause <= STOP_ILLEGAL;
            end
            // El dato de un load está disponible recién en MEM/WB.
            else if (load_use_hazard) begin
                idex_valid       <= 1'b0;
                ifid_valid       <= ifid_valid;
                ifid_pc          <= ifid_pc;
                ifid_instruction <= ifid_instruction;
                pc               <= pc;
            end
            // Fallo al buscar la próxima instrucción: la actual aún avanza.
            else if (!fetch_stopped && !fetch_address_valid) begin
                ifid_valid    <= 1'b0;
                fetch_stopped <= 1'b1;
                pending_cause <= STOP_PC_RANGE;
            end
            else if (!fetch_stopped &&
                     (i_imem_read_misaligned || i_imem_read_out_of_range)) begin
                ifid_valid    <= 1'b0;
                fetch_stopped <= 1'b1;
                pending_cause <= STOP_IMEM_FAULT;
            end

            // Se declara detenido recién después de vaciar los cuatro latches.
            if (fetch_stopped && !ifid_valid && !idex_valid &&
                !exmem_valid && !memwb_valid) begin
                o_running    <= 1'b0;
                o_halted     <= 1'b1;
                o_stop_cause <= pending_cause;
            end
        end
    end

endmodule
