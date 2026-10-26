`timescale 1ns / 1ps

module rv32_data_memory #(
    parameter integer WORDS = 1024
)(
    input  logic        i_clk,
    input  logic        i_rst,

    input  logic        i_read_enable,
    input  logic [31:0] i_read_addr,
    input  logic [1:0]  i_read_size,
    input  logic        i_read_unsigned,
    output logic [31:0] o_read_data,
    output logic        o_read_misaligned,
    output logic        o_read_out_of_range,

    input  logic        i_write_enable,
    input  logic [31:0] i_write_addr,
    input  logic [1:0]  i_write_size,
    input  logic [31:0] i_write_data,
    output logic        o_write_misaligned,
    output logic        o_write_out_of_range
);

    localparam integer MEMORY_BYTES = WORDS * 4;
    localparam integer ADDR_WIDTH   = $clog2(WORDS);
    localparam logic [1:0] MEM_BYTE = 2'd0;
    localparam logic [1:0] MEM_HALF = 2'd1;
    localparam logic [1:0] MEM_WORD = 2'd2;

    (* ram_style = "block" *) logic [31:0] memory [0:WORDS-1];

    logic [31:0] read_word;
    logic [1:0]  read_offset;
    logic [1:0]  read_size;
    logic        read_unsigned;
    logic [7:0]  selected_byte;
    logic [15:0] selected_half;

    function automatic logic is_misaligned(
        input logic [31:0] address,
        input logic [1:0]  size
    );
        case (size)
            MEM_BYTE: is_misaligned = 1'b0;
            MEM_HALF: is_misaligned = address[0];
            MEM_WORD: is_misaligned = |address[1:0];
            default:  is_misaligned = 1'b1;
        endcase
    endfunction

    function automatic logic is_out_of_range(
        input logic [31:0] address,
        input logic [1:0]  size
    );
        logic upper_nonzero;
        logic last_word;
        begin
        // WORDS es potencia de dos. Esta forma evita un comparador de 32 bits
        // en el camino de medio ciclo que habilita la BRAM en negedge.
        upper_nonzero = |address[31:ADDR_WIDTH+2];
        last_word = &address[ADDR_WIDTH+1:2];
        case (size)
            MEM_BYTE: is_out_of_range = upper_nonzero;
            MEM_HALF: is_out_of_range = upper_nonzero ||
                                             (last_word && (&address[1:0]));
            MEM_WORD: is_out_of_range = upper_nonzero ||
                                             (last_word && (|address[1:0]));
            default:  is_out_of_range = 1'b1;
        endcase
        end
    endfunction

    always_comb begin
        o_write_misaligned  = is_misaligned(i_write_addr, i_write_size);
        o_write_out_of_range = is_out_of_range(i_write_addr, i_write_size);

        case (read_offset)
            2'd0: selected_byte = read_word[7:0];
            2'd1: selected_byte = read_word[15:8];
            2'd2: selected_byte = read_word[23:16];
            default: selected_byte = read_word[31:24];
        endcase

        selected_half = read_offset[1] ? read_word[31:16] : read_word[15:0];

        if (o_read_misaligned || o_read_out_of_range) begin
            o_read_data = 32'h0000_0000;
        end
        else begin
            case (read_size)
                MEM_BYTE: o_read_data = read_unsigned
                    ? {24'h000000, selected_byte}
                    : {{24{selected_byte[7]}}, selected_byte};
                MEM_HALF: o_read_data = read_unsigned
                    ? {16'h0000, selected_half}
                    : {{16{selected_half[15]}}, selected_half};
                MEM_WORD: o_read_data = read_word;
                default:  o_read_data = 32'h0000_0000;
            endcase
        end
    end

    // Stores y programación de DMEM en flanco positivo.
    always_ff @(posedge i_clk) begin
        if (i_write_enable && !o_write_misaligned && !o_write_out_of_range) begin
            case (i_write_size)
                MEM_BYTE: begin
                    case (i_write_addr[1:0])
                        2'd0: memory[i_write_addr[ADDR_WIDTH+1:2]][7:0]   <= i_write_data[7:0];
                        2'd1: memory[i_write_addr[ADDR_WIDTH+1:2]][15:8]  <= i_write_data[7:0];
                        2'd2: memory[i_write_addr[ADDR_WIDTH+1:2]][23:16] <= i_write_data[7:0];
                        2'd3: memory[i_write_addr[ADDR_WIDTH+1:2]][31:24] <= i_write_data[7:0];
                        default: ;
                    endcase
                end
                MEM_HALF: begin
                    if (i_write_addr[1])
                        memory[i_write_addr[ADDR_WIDTH+1:2]][31:16] <= i_write_data[15:0];
                    else
                        memory[i_write_addr[ADDR_WIDTH+1:2]][15:0] <= i_write_data[15:0];
                end
                MEM_WORD: memory[i_write_addr[ADDR_WIDTH+1:2]] <= i_write_data;
                default: ;
            endcase
        end
    end

    // Loads: captura de palabra y metadatos en flanco negativo.
    always_ff @(negedge i_clk) begin
        if (i_rst) begin
            read_word           <= 32'h0000_0000;
            read_offset         <= 2'd0;
            read_size           <= MEM_WORD;
            read_unsigned       <= 1'b0;
            o_read_misaligned   <= 1'b0;
            o_read_out_of_range <= 1'b0;
        end
        else begin
            o_read_misaligned   <= 1'b0;
            o_read_out_of_range <= 1'b0;
            if (i_read_enable) begin
                read_offset         <= i_read_addr[1:0];
                read_size           <= i_read_size;
                read_unsigned       <= i_read_unsigned;
                o_read_misaligned   <= is_misaligned(i_read_addr, i_read_size);
                o_read_out_of_range <= is_out_of_range(i_read_addr, i_read_size);
                if (!is_misaligned(i_read_addr, i_read_size) &&
                    !is_out_of_range(i_read_addr, i_read_size))
                    read_word <= memory[i_read_addr[ADDR_WIDTH+1:2]];
                else
                    read_word <= 32'h0000_0000;
            end
        end
    end

endmodule
