"""Prueba la ALU RV32 cargada en la Basys 3 mediante UART."""

from __future__ import annotations

import argparse
import sys
import time

try:
    import serial
except ModuleNotFoundError:
    print("Falta pyserial. Instalalo con: py -m pip install pyserial")
    raise SystemExit(1)


BAUD_RATE = 115_200

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

TESTS = [
    ("ADD", ALU_ADD, 10, 5, 15),
    ("ADD overflow modular", ALU_ADD, 0xFFFF_FFFF, 1, 0),
    ("SUB", ALU_SUB, 10, 3, 7),
    ("SUB negativo", ALU_SUB, 3, 10, 0xFFFF_FFF9),
    ("SLL", ALU_SLL, 1, 31, 0x8000_0000),
    ("SRL", ALU_SRL, 0x8000_0000, 1, 0x4000_0000),
    ("SRA", ALU_SRA, 0x8000_0000, 1, 0xC000_0000),
    ("AND", ALU_AND, 0xAA55_F00F, 0x0FF0_55AA, 0x0A50_500A),
    ("OR", ALU_OR, 0xAA55_F00F, 0x0FF0_55AA, 0xAFF5_F5AF),
    ("XOR", ALU_XOR, 0xAA55_F00F, 0x0FF0_55AA, 0xA5A5_A5A5),
    ("SLT signed", ALU_SLT, 0xFFFF_FFFF, 1, 1),
    ("SLTU", ALU_SLTU, 0xFFFF_FFFF, 1, 0),
    ("COPY_B", ALU_COPY_B, 0xDEAD_BEEF, 0x1234_5678, 0x1234_5678),
]


def execute(uart: serial.Serial, a: int, b: int, operation: int) -> int:
    request = (
        (a & 0xFFFF_FFFF).to_bytes(4, "little")
        + (b & 0xFFFF_FFFF).to_bytes(4, "little")
        + bytes([operation & 0x0F])
    )
    uart.write(request)
    uart.flush()
    response = uart.read(4)
    if len(response) != 4:
        raise TimeoutError(f"Respuesta incompleta: {len(response)}/4 bytes")
    return int.from_bytes(response, "little")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("port", help="Puerto serie, por ejemplo COM7")
    args = parser.parse_args()

    errors = 0
    with serial.Serial(args.port, BAUD_RATE, timeout=2, write_timeout=2) as uart:
        time.sleep(0.2)
        uart.reset_input_buffer()
        uart.reset_output_buffer()

        for name, operation, a, b, expected in TESTS:
            received = execute(uart, a, b, operation)
            ok = received == expected
            print(
                f"{'OK' if ok else 'ERROR':5} {name:21} "
                f"A=0x{a:08X} B=0x{b:08X} "
                f"resultado=0x{received:08X}"
            )
            errors += not ok

    if errors:
        print(f"RESULTADO: {errors} errores")
        return 1

    print("RESULTADO: ALU RV32 EN PLACA OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
