"""Prueba el banco de registros RV32 cargado en la Basys 3 mediante UART."""

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
CMD_WRITE = 0x01
CMD_READ2 = 0x02


def read_exact(uart: serial.Serial, size: int) -> bytes:
    response = uart.read(size)
    if len(response) != size:
        raise TimeoutError(f"Respuesta incompleta: {len(response)}/{size} bytes")
    return response


def write_register(uart: serial.Serial, address: int, value: int) -> None:
    request = bytes([CMD_WRITE, address & 0x1F]) + (
        value & 0xFFFF_FFFF
    ).to_bytes(4, "little")
    uart.write(request)
    uart.flush()
    if read_exact(uart, 1) != b"\xA1":
        raise RuntimeError("ACK de escritura inválido")


def read_pair(uart: serial.Serial, address_1: int, address_2: int) -> tuple[int, int]:
    uart.write(bytes([CMD_READ2, address_1 & 0x1F, address_2 & 0x1F]))
    uart.flush()
    response = read_exact(uart, 8)
    return (
        int.from_bytes(response[0:4], "little"),
        int.from_bytes(response[4:8], "little"),
    )


def check_pair(
    uart: serial.Serial,
    address_1: int,
    expected_1: int,
    address_2: int,
    expected_2: int,
) -> int:
    value_1, value_2 = read_pair(uart, address_1, address_2)
    ok = value_1 == expected_1 and value_2 == expected_2
    print(
        f"{'OK' if ok else 'ERROR':5} "
        f"x{address_1:02d}=0x{value_1:08X} "
        f"x{address_2:02d}=0x{value_2:08X}"
    )
    return 0 if ok else 1


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("port", help="Puerto serie, por ejemplo COM7")
    args = parser.parse_args()

    errors = 0
    with serial.Serial(args.port, BAUD_RATE, timeout=2, write_timeout=2) as uart:
        time.sleep(0.2)
        uart.reset_input_buffer()
        uart.reset_output_buffer()

        errors += check_pair(uart, 0, 0, 31, 0)

        write_register(uart, 1, 0x1234_5678)
        write_register(uart, 2, 0xCAFE_BABE)
        write_register(uart, 31, 0xDEAD_BEEF)
        errors += check_pair(uart, 1, 0x1234_5678, 2, 0xCAFE_BABE)
        errors += check_pair(uart, 31, 0xDEAD_BEEF, 1, 0x1234_5678)

        write_register(uart, 0, 0xFFFF_FFFF)
        errors += check_pair(uart, 0, 0, 31, 0xDEAD_BEEF)

        write_register(uart, 1, 0xA5A5_5A5A)
        errors += check_pair(uart, 1, 0xA5A5_5A5A, 1, 0xA5A5_5A5A)

    if errors:
        print(f"RESULTADO: BANCO DE REGISTROS CON {errors} ERRORES")
        return 1

    print("RESULTADO: BANCO DE REGISTROS RV32 EN PLACA OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
