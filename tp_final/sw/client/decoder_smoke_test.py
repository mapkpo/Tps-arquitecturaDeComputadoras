"""Prueba el decoder RV32I y los inmediatos cargados en la Basys 3 por UART."""

from __future__ import annotations

import argparse
from dataclasses import dataclass
import sys
import time

try:
    import serial
except ModuleNotFoundError:
    print("Falta pyserial. Instalalo con: py -m pip install pyserial")
    raise SystemExit(1)


BAUD_RATE = 115_200
CMD_DECODE = 0x03

ALU_ADD = 0x0
ALU_SUB = 0x1
ALU_SLL = 0x2
ALU_SRL = 0x3
ALU_SRA = 0x4
ALU_AND = 0x5
ALU_OR = 0x6
ALU_XOR = 0x7
ALU_SLT = 0x8
ALU_SLTU = 0x9
ALU_COPY_B = 0xA

IMM_NONE = 0
IMM_I = 1
IMM_S = 2
IMM_B = 3
IMM_U = 4
IMM_J = 5

MEM_BYTE = 0
MEM_HALF = 1
MEM_WORD = 2


@dataclass(frozen=True)
class Case:
    name: str
    instruction: int
    status: int
    alu_op: int = ALU_ADD
    imm_type: int = IMM_NONE
    mem_ctrl: int = MEM_WORD
    branch: int = 0
    jump: int = 0
    wb_sel: int = 0
    immediate: int = 0

    def expected_response(self) -> bytes:
        instruction = self.instruction & 0xFFFF_FFFF
        header = bytes(
            [
                self.status,
                (instruction >> 15) & 0x1F,
                (instruction >> 20) & 0x1F,
                (instruction >> 7) & 0x1F,
                self.alu_op,
                self.imm_type,
                self.mem_ctrl,
                self.branch,
                self.jump,
                self.wb_sel,
            ]
        )
        return header + (self.immediate & 0xFFFF_FFFF).to_bytes(4, "little")


def status(
    *,
    legal: bool = True,
    halt: bool = False,
    uses_rs1: bool = False,
    uses_rs2: bool = False,
    reg_write: bool = False,
    mem_read: bool = False,
    mem_write: bool = False,
    alu_src_imm: bool = False,
) -> int:
    return (
        int(legal)
        | (int(halt) << 1)
        | (int(uses_rs1) << 2)
        | (int(uses_rs2) << 3)
        | (int(reg_write) << 4)
        | (int(mem_read) << 5)
        | (int(mem_write) << 6)
        | (int(alu_src_imm) << 7)
    )


def sign_extend(value: int, bits: int) -> int:
    value &= (1 << bits) - 1
    if value & (1 << (bits - 1)):
        value -= 1 << bits
    return value & 0xFFFF_FFFF


def encode_r(funct7: int, funct3: int) -> int:
    return (
        ((funct7 & 0x7F) << 25)
        | (2 << 20)
        | (1 << 15)
        | ((funct3 & 7) << 12)
        | (3 << 7)
        | 0x33
    )


def encode_i(immediate: int, funct3: int, opcode: int) -> int:
    return (
        ((immediate & 0xFFF) << 20)
        | (1 << 15)
        | ((funct3 & 7) << 12)
        | (3 << 7)
        | (opcode & 0x7F)
    )


def encode_s(immediate: int, funct3: int) -> int:
    imm = immediate & 0xFFF
    return (
        (((imm >> 5) & 0x7F) << 25)
        | (2 << 20)
        | (1 << 15)
        | ((funct3 & 7) << 12)
        | ((imm & 0x1F) << 7)
        | 0x23
    )


def encode_b(immediate: int, funct3: int) -> int:
    imm = immediate & 0x1FFF
    return (
        (((imm >> 12) & 1) << 31)
        | (((imm >> 5) & 0x3F) << 25)
        | (2 << 20)
        | (1 << 15)
        | ((funct3 & 7) << 12)
        | (((imm >> 1) & 0xF) << 8)
        | (((imm >> 11) & 1) << 7)
        | 0x63
    )


def encode_j(immediate: int) -> int:
    imm = immediate & 0x1F_FFFF
    return (
        (((imm >> 20) & 1) << 31)
        | (((imm >> 1) & 0x3FF) << 21)
        | (((imm >> 11) & 1) << 20)
        | (((imm >> 12) & 0xFF) << 12)
        | (3 << 7)
        | 0x6F
    )


def build_cases() -> list[Case]:
    cases: list[Case] = []
    r_status = status(uses_rs1=True, uses_rs2=True, reg_write=True)
    for name, funct7, funct3, alu_op in (
        ("ADD", 0x00, 0b000, ALU_ADD),
        ("SUB", 0x20, 0b000, ALU_SUB),
        ("SLL", 0x00, 0b001, ALU_SLL),
        ("SLT", 0x00, 0b010, ALU_SLT),
        ("SLTU", 0x00, 0b011, ALU_SLTU),
        ("XOR", 0x00, 0b100, ALU_XOR),
        ("SRL", 0x00, 0b101, ALU_SRL),
        ("SRA", 0x20, 0b101, ALU_SRA),
        ("OR", 0x00, 0b110, ALU_OR),
        ("AND", 0x00, 0b111, ALU_AND),
    ):
        cases.append(Case(name, encode_r(funct7, funct3), r_status, alu_op=alu_op))

    i_status = status(uses_rs1=True, reg_write=True, alu_src_imm=True)
    for name, imm, funct3, alu_op in (
        ("ADDI", -16, 0b000, ALU_ADD),
        ("SLTI", 0x55, 0b010, ALU_SLT),
        ("SLTIU", 0x55, 0b011, ALU_SLTU),
        ("XORI", 0x55, 0b100, ALU_XOR),
        ("ORI", 0x55, 0b110, ALU_OR),
        ("ANDI", 0x55, 0b111, ALU_AND),
        ("SLLI", 0x003, 0b001, ALU_SLL),
        ("SRLI", 0x003, 0b101, ALU_SRL),
        ("SRAI", 0x403, 0b101, ALU_SRA),
    ):
        cases.append(
            Case(
                name,
                encode_i(imm, funct3, 0x13),
                i_status,
                alu_op=alu_op,
                imm_type=IMM_I,
                immediate=sign_extend(imm, 12),
            )
        )

    load_status = status(
        uses_rs1=True, reg_write=True, mem_read=True, alu_src_imm=True
    )
    for name, funct3, size, unsigned in (
        ("LB", 0b000, MEM_BYTE, False),
        ("LH", 0b001, MEM_HALF, False),
        ("LW", 0b010, MEM_WORD, False),
        ("LBU", 0b100, MEM_BYTE, True),
        ("LHU", 0b101, MEM_HALF, True),
    ):
        cases.append(
            Case(
                name,
                encode_i(-8, funct3, 0x03),
                load_status,
                imm_type=IMM_I,
                mem_ctrl=size | (int(unsigned) << 2),
                wb_sel=1,
                immediate=0xFFFF_FFF8,
            )
        )

    store_status = status(
        uses_rs1=True, uses_rs2=True, mem_write=True, alu_src_imm=True
    )
    for name, funct3, size in (
        ("SB", 0b000, MEM_BYTE),
        ("SH", 0b001, MEM_HALF),
        ("SW", 0b010, MEM_WORD),
    ):
        cases.append(
            Case(
                name,
                encode_s(-12, funct3),
                store_status,
                imm_type=IMM_S,
                mem_ctrl=size,
                immediate=0xFFFF_FFF4,
            )
        )

    branch_status = status(uses_rs1=True, uses_rs2=True)
    cases.extend(
        [
            Case(
                "BEQ",
                encode_b(-4, 0b000),
                branch_status,
                alu_op=ALU_SUB,
                imm_type=IMM_B,
                branch=1,
                immediate=0xFFFF_FFFC,
            ),
            Case(
                "BNE",
                encode_b(-4, 0b001),
                branch_status,
                alu_op=ALU_SUB,
                imm_type=IMM_B,
                branch=2,
                immediate=0xFFFF_FFFC,
            ),
            Case(
                "LUI",
                (0xABCDE << 12) | (3 << 7) | 0x37,
                status(reg_write=True, alu_src_imm=True),
                alu_op=ALU_COPY_B,
                imm_type=IMM_U,
                immediate=0xABCDE000,
            ),
            Case(
                "JAL",
                encode_j(-8),
                status(reg_write=True),
                imm_type=IMM_J,
                jump=1,
                wb_sel=2,
                immediate=0xFFFF_FFF8,
            ),
            Case(
                "JALR",
                encode_i(12, 0b000, 0x67),
                status(uses_rs1=True, reg_write=True, alu_src_imm=True),
                imm_type=IMM_I,
                jump=2,
                wb_sel=2,
                immediate=12,
            ),
            Case("EBREAK/HALT", 0x0010_0073, status(halt=True)),
            Case("ILLEGAL ZERO", 0x0000_0000, status(legal=False)),
            Case(
                "ILLEGAL FUNCT7",
                encode_r(0x7F, 0b000),
                status(legal=False),
            ),
            Case(
                "ILLEGAL LOAD",
                encode_i(0, 0b011, 0x03),
                status(legal=False),
            ),
        ]
    )
    return cases


def read_exact(uart: serial.Serial, size: int) -> bytes:
    response = uart.read(size)
    if len(response) != size:
        raise TimeoutError(f"Respuesta incompleta: {len(response)}/{size} bytes")
    return response


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("port", help="Puerto serie, por ejemplo COM7")
    args = parser.parse_args()

    errors = 0
    with serial.Serial(args.port, BAUD_RATE, timeout=2, write_timeout=2) as uart:
        time.sleep(0.2)
        uart.reset_input_buffer()
        uart.reset_output_buffer()

        for case in build_cases():
            request = bytes([CMD_DECODE]) + case.instruction.to_bytes(4, "little")
            uart.write(request)
            uart.flush()
            response = read_exact(uart, 14)
            expected = case.expected_response()
            ok = response == expected
            print(
                f"{'OK' if ok else 'ERROR':5} {case.name:16} "
                f"instr=0x{case.instruction:08X} imm=0x{int.from_bytes(response[10:14], 'little'):08X}"
            )
            if not ok:
                errors += 1
                print(f"      esperado={expected.hex(' ')}")
                print(f"      obtenido={response.hex(' ')}")

    if errors:
        print(f"RESULTADO: DECODER RV32I CON {errors} ERRORES")
        return 1

    print("RESULTADO: DECODER E INMEDIATOS RV32I EN PLACA OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
