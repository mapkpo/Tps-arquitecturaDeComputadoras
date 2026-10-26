"""Ensamblador de dos pasadas para el subconjunto RV32I de la Basys 3.

Uso: py sw/client/rv32i_assembler.py programa.asm [-o salida.hex]
Genera .hex, .bin little-endian y .map. No requiere un toolchain externo.
"""

from __future__ import annotations

import argparse
import re
from dataclasses import dataclass
from pathlib import Path


class AssemblyError(ValueError):
    """Error de fuente con numero de linea."""


ABI = "zero ra sp gp tp t0 t1 t2 s0 s1 a0 a1 a2 a3 a4 a5 a6 a7 s2 s3 s4 s5 s6 s7 s8 s9 s10 s11 t3 t4 t5 t6".split()
REGISTERS = {f"x{i}": i for i in range(32)} | dict(zip(ABI, range(32))) | {"fp": 8}
R_OPS = {
    "add": (0, 0), "sub": (0, 32), "sll": (1, 0), "slt": (2, 0),
    "sltu": (3, 0), "xor": (4, 0), "srl": (5, 0), "sra": (5, 32),
    "or": (6, 0), "and": (7, 0),
}
I_OPS = {"addi": 0, "slti": 2, "sltiu": 3, "xori": 4, "ori": 6, "andi": 7}
LOADS = {"lb": 0, "lh": 1, "lw": 2, "lbu": 4, "lhu": 5}
STORES = {"sb": 0, "sh": 1, "sw": 2}
LABEL = re.compile(r"^([A-Za-z_.$][\w.$]*):")


@dataclass(frozen=True)
class Assembly:
    words: tuple[int, ...]
    labels: dict[str, int]
    listing: tuple[tuple[int, int, str], ...]


def number(token: str) -> int:
    try:
        return int(token, 16 if token.lstrip("+-").lower().startswith("0x") else 10)
    except ValueError:
        raise ValueError(f"Literal invalido: {token}") from None


def bounded(value: int, low: int, high: int, name: str) -> int:
    if not low <= value <= high:
        raise ValueError(f"{name} fuera de rango [{low}, {high}]: {value}")
    return value


def register(token: str) -> int:
    try:
        return REGISTERS[token.lower()]
    except KeyError:
        raise ValueError(f"Registro invalido: {token}") from None


def operands(args: list[str], count: int) -> None:
    if len(args) != count or any(not arg for arg in args):
        raise ValueError(f"Se esperaban {count} operandos separados por comas")


def immediate(token: str) -> int:
    return bounded(number(token), -2048, 2047, "Inmediato") & 0xFFF


def memory(token: str) -> tuple[int, int]:
    match = re.fullmatch(r"\s*([^()]+)\(\s*([^()\s]+)\s*\)\s*", token)
    if not match:
        raise ValueError("Se esperaba desplazamiento(registro), por ejemplo 0(x2)")
    return immediate(match[1].strip()), register(match[2])


def relative(token: str, pc: int, labels: dict[str, int], bits: int) -> int:
    if token in labels:
        value = labels[token] - pc
    else:
        try:
            value = number(token)
        except ValueError:
            raise ValueError(f"Etiqueta desconocida o desplazamiento invalido: {token}") from None
    bounded(value, -(1 << (bits - 1)), (1 << (bits - 1)) - 1, "Salto")
    # Este core no implementa instrucciones comprimidas: destinos de 4 bytes.
    if (pc + value) % 4:
        raise ValueError("Destino de salto desalineado: debe ser multiplo de 4 bytes")
    return value & ((1 << bits) - 1)


def encode(text: str, pc: int, labels: dict[str, int]) -> int:
    parts = text.split(None, 1)
    op = parts[0].lower()
    args = [arg.strip() for arg in parts[1].split(",")] if len(parts) == 2 else []
    if op in ("nop", "halt", "ebreak"):
        operands(args, 0)
        return 0x13 if op == "nop" else 0x00100073
    if op == ".word":
        operands(args, 1)
        return bounded(number(args[0]), -(1 << 31), (1 << 32) - 1, ".word") & 0xFFFFFFFF
    if op in R_OPS:
        operands(args, 3)
        rd, rs1, rs2 = map(register, args)
        f3, f7 = R_OPS[op]
        return f7 << 25 | rs2 << 20 | rs1 << 15 | f3 << 12 | rd << 7 | 0x33
    if op in I_OPS or op in ("slli", "srli", "srai"):
        operands(args, 3)
        rd, rs1 = map(register, args[:2])
        if op in I_OPS:
            imm, f3 = immediate(args[2]), I_OPS[op]
        else:
            imm = bounded(number(args[2]), 0, 31, "Desplazamiento")
            f3 = 1 if op == "slli" else 5
            if op == "srai":
                imm |= 0x400
        return imm << 20 | rs1 << 15 | f3 << 12 | rd << 7 | 0x13
    if op in LOADS or op == "jalr":
        # Se aceptan jalr rd, offset(rs1) y jalr rd, rs1, offset.
        if op == "jalr" and len(args) == 3:
            operands(args, 3)
            imm, rs1 = immediate(args[2]), register(args[1])
        else:
            operands(args, 2)
            imm, rs1 = memory(args[1])
        rd = register(args[0])
        f3, opcode = (0, 0x67) if op == "jalr" else (LOADS[op], 0x03)
        return imm << 20 | rs1 << 15 | f3 << 12 | rd << 7 | opcode
    if op in STORES:
        operands(args, 2)
        rs2 = register(args[0])
        imm, rs1 = memory(args[1])
        return (imm >> 5) << 25 | rs2 << 20 | rs1 << 15 | STORES[op] << 12 | (imm & 31) << 7 | 0x23
    if op in ("beq", "bne"):
        operands(args, 3)
        rs1, rs2 = map(register, args[:2])
        imm = relative(args[2], pc, labels, 13)
        return ((imm >> 12) & 1) << 31 | ((imm >> 5) & 63) << 25 | rs2 << 20 | rs1 << 15 | (op == "bne") << 12 | ((imm >> 1) & 15) << 8 | ((imm >> 11) & 1) << 7 | 0x63
    if op == "lui":
        operands(args, 2)
        imm = bounded(number(args[1]), -(1 << 19), (1 << 20) - 1, "Inmediato LUI")
        return (imm & 0xFFFFF) << 12 | register(args[0]) << 7 | 0x37
    if op == "jal":
        operands(args, 2)
        imm = relative(args[1], pc, labels, 21)
        return ((imm >> 20) & 1) << 31 | ((imm >> 1) & 1023) << 21 | ((imm >> 11) & 1) << 20 | ((imm >> 12) & 255) << 12 | register(args[0]) << 7 | 0x6F
    raise ValueError(f"Instruccion o directiva no soportada: {op}")


def assemble(source: str) -> Assembly:
    labels: dict[str, int] = {}
    lines: list[tuple[int, int, str]] = []
    pc = 0
    for line_number, raw in enumerate(source.lstrip("\ufeff").splitlines(), 1):
        text = re.split(r"#|;|//", raw, maxsplit=1)[0].strip()
        while match := LABEL.match(text):
            label = match[1]
            if label in labels:
                raise AssemblyError(f"Linea {line_number}: etiqueta duplicada: {label}")
            labels[label] = pc
            text = text[match.end():].strip()
        if text:
            lines.append((line_number, pc, text))
            pc += 4
            if pc > 4096:
                raise AssemblyError(f"Linea {line_number}: el programa supera las 1024 palabras de IMEM")
    if not lines:
        raise AssemblyError("El programa no contiene instrucciones")
    words = []
    for line_number, pc, text in lines:
        try:
            words.append(encode(text, pc, labels))
        except ValueError as exc:
            raise AssemblyError(f"Linea {line_number}: {exc}") from None
    if 0x00100073 not in words:
        raise AssemblyError("El programa debe incluir halt o ebreak explicitamente")
    return Assembly(tuple(words), labels, tuple(lines))


def assemble_file(path: str | Path) -> Assembly:
    return assemble(Path(path).read_text(encoding="utf-8-sig"))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("-o", "--output", type=Path, help="Ruta .hex; tambien genera .bin y .map")
    args = parser.parse_args()
    try:
        result = assemble_file(args.source)
        output = args.output or args.source.with_suffix(".hex")
        if output.suffix.lower() != ".hex":
            raise ValueError("La salida debe tener extension .hex")
        targets = [output, output.with_suffix(".bin"), output.with_suffix(".map")]
        if args.source.resolve() in [target.resolve() for target in targets]:
            raise ValueError("La salida no puede sobrescribir el archivo fuente")
        mapping = ["Direccion  Codigo     Linea  Fuente"]
        mapping += [f"{pc:08X}   {word:08X}   {line:5d}  {text}" for (line, pc, text), word in zip(result.listing, result.words)]
        mapping += ["", "Etiquetas:"] + [f"{address:08X} {label}" for label, address in result.labels.items()]
        output.write_text("".join(f"{word:08X}\n" for word in result.words), encoding="utf-8")
        targets[1].write_bytes(b"".join(word.to_bytes(4, "little") for word in result.words))
        targets[2].write_text("\n".join(mapping) + "\n", encoding="utf-8")
    except (OSError, ValueError) as exc:
        parser.exit(1, f"Error: {exc}\n")
    print(f"Ensamblado OK: {len(result.words)} palabras. Archivos: {', '.join(map(str, targets))}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
