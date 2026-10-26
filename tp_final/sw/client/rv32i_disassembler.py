"""Desensamblador mínimo del subconjunto RV32I implementado por el TP."""

from __future__ import annotations


ABI = (
    "zero", "ra", "sp", "gp", "tp", "t0", "t1", "t2",
    "s0", "s1", "a0", "a1", "a2", "a3", "a4", "a5",
    "a6", "a7", "s2", "s3", "s4", "s5", "s6", "s7",
    "s8", "s9", "s10", "s11", "t3", "t4", "t5", "t6",
)


def _reg(index: int) -> str:
    return f"x{index} ({ABI[index]})"


def _signed(value: int, bits: int) -> int:
    sign = 1 << (bits - 1)
    return (value & (sign - 1)) - (value & sign)


def disassemble(instruction: int) -> str:
    instruction &= 0xFFFF_FFFF
    if instruction == 0x00100073:
        return "ebreak"

    opcode = instruction & 0x7F
    rd = (instruction >> 7) & 0x1F
    funct3 = (instruction >> 12) & 7
    rs1 = (instruction >> 15) & 0x1F
    rs2 = (instruction >> 20) & 0x1F
    funct7 = (instruction >> 25) & 0x7F

    if opcode == 0x33:
        names = {
            (0, 0x00): "add", (0, 0x20): "sub", (1, 0x00): "sll",
            (2, 0x00): "slt", (3, 0x00): "sltu", (4, 0x00): "xor",
            (5, 0x00): "srl", (5, 0x20): "sra", (6, 0x00): "or",
            (7, 0x00): "and",
        }
        name = names.get((funct3, funct7))
        if name:
            return f"{name} {_reg(rd)}, {_reg(rs1)}, {_reg(rs2)}"

    if opcode == 0x13:
        immediate = _signed(instruction >> 20, 12)
        names = {0: "addi", 2: "slti", 3: "sltiu", 4: "xori", 6: "ori", 7: "andi"}
        if funct3 in names:
            return f"{names[funct3]} {_reg(rd)}, {_reg(rs1)}, {immediate}"
        if funct3 == 1 and funct7 == 0:
            return f"slli {_reg(rd)}, {_reg(rs1)}, {rs2}"
        if funct3 == 5 and funct7 in (0, 0x20):
            name = "srai" if funct7 == 0x20 else "srli"
            return f"{name} {_reg(rd)}, {_reg(rs1)}, {rs2}"

    if opcode == 0x03:
        names = {0: "lb", 1: "lh", 2: "lw", 4: "lbu", 5: "lhu"}
        if funct3 in names:
            immediate = _signed(instruction >> 20, 12)
            return f"{names[funct3]} {_reg(rd)}, {immediate}({_reg(rs1)})"

    if opcode == 0x23:
        immediate = ((instruction >> 25) << 5) | ((instruction >> 7) & 0x1F)
        immediate = _signed(immediate, 12)
        names = {0: "sb", 1: "sh", 2: "sw"}
        if funct3 in names:
            return f"{names[funct3]} {_reg(rs2)}, {immediate}({_reg(rs1)})"

    if opcode == 0x63:
        immediate = (
            ((instruction >> 31) << 12)
            | (((instruction >> 7) & 1) << 11)
            | (((instruction >> 25) & 0x3F) << 5)
            | (((instruction >> 8) & 0xF) << 1)
        )
        names = {0: "beq", 1: "bne"}
        if funct3 in names:
            return f"{names[funct3]} {_reg(rs1)}, {_reg(rs2)}, {_signed(immediate, 13):+d}"

    if opcode == 0x37:
        return f"lui {_reg(rd)}, 0x{instruction >> 12:05X}"

    if opcode == 0x6F:
        immediate = (
            ((instruction >> 31) << 20)
            | (((instruction >> 12) & 0xFF) << 12)
            | (((instruction >> 20) & 1) << 11)
            | (((instruction >> 21) & 0x3FF) << 1)
        )
        return f"jal {_reg(rd)}, {_signed(immediate, 21):+d}"

    if opcode == 0x67 and funct3 == 0:
        immediate = _signed(instruction >> 20, 12)
        return f"jalr {_reg(rd)}, {immediate}({_reg(rs1)})"

    return f".word 0x{instruction:08X}"
