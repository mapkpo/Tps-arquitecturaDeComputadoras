"""Prueba IMEM y DMEM RV32 cargadas en la Basys 3 mediante UART."""

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
CMD_IMEM_WRITE = 0x10
CMD_IMEM_READ = 0x11
CMD_DMEM_WRITE = 0x20
CMD_DMEM_READ = 0x21

MEM_BYTE = 0
MEM_HALF = 1
MEM_WORD = 2


def read_exact(uart: serial.Serial, size: int) -> bytes:
    response = uart.read(size)
    if len(response) != size:
        raise TimeoutError(f"Respuesta incompleta: {len(response)}/{size} bytes")
    return response


def imem_write(uart: serial.Serial, address: int, data: int) -> int:
    request = (
        bytes([CMD_IMEM_WRITE])
        + (address & 0xFFFF_FFFF).to_bytes(4, "little")
        + (data & 0xFFFF_FFFF).to_bytes(4, "little")
    )
    uart.write(request)
    uart.flush()
    return read_exact(uart, 1)[0]


def imem_read(uart: serial.Serial, address: int) -> tuple[int, int]:
    uart.write(
        bytes([CMD_IMEM_READ])
        + (address & 0xFFFF_FFFF).to_bytes(4, "little")
    )
    uart.flush()
    response = read_exact(uart, 5)
    return response[0], int.from_bytes(response[1:5], "little")


def dmem_write(uart: serial.Serial, size: int, address: int, data: int) -> int:
    request = (
        bytes([CMD_DMEM_WRITE, size & 0x03])
        + (address & 0xFFFF_FFFF).to_bytes(4, "little")
        + (data & 0xFFFF_FFFF).to_bytes(4, "little")
    )
    uart.write(request)
    uart.flush()
    return read_exact(uart, 1)[0]


def dmem_read(
    uart: serial.Serial, size: int, unsigned_load: bool, address: int
) -> tuple[int, int]:
    request = (
        bytes([CMD_DMEM_READ, size & 0x03, int(unsigned_load)])
        + (address & 0xFFFF_FFFF).to_bytes(4, "little")
    )
    uart.write(request)
    uart.flush()
    response = read_exact(uart, 5)
    return response[0], int.from_bytes(response[1:5], "little")


def check_write(name: str, status: int, expected_status: int) -> int:
    ok = status == expected_status
    print(
        f"{'OK' if ok else 'ERROR':5} {name:22} "
        f"status=0x{status:02X}"
    )
    return 0 if ok else 1


def check_read(
    name: str,
    result: tuple[int, int],
    expected_status: int,
    expected_data: int,
) -> int:
    status, data = result
    expected_data &= 0xFFFF_FFFF
    ok = status == expected_status and data == expected_data
    print(
        f"{'OK' if ok else 'ERROR':5} {name:22} "
        f"status=0x{status:02X} data=0x{data:08X}"
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

        errors += check_write("IMEM write 0", imem_write(uart, 0, 0x00100093), 0)
        errors += check_write("IMEM write 4", imem_write(uart, 4, 0x00208113), 0)
        errors += check_write(
            "IMEM write final", imem_write(uart, 4092, 0x00100073), 0
        )
        errors += check_read("IMEM read 0", imem_read(uart, 0), 0, 0x00100093)
        errors += check_read("IMEM read 4", imem_read(uart, 4), 0, 0x00208113)
        errors += check_read(
            "IMEM read final", imem_read(uart, 4092), 0, 0x00100073
        )
        errors += check_write(
            "IMEM desalineada", imem_write(uart, 2, 0xDEADBEEF), 1
        )
        errors += check_write(
            "IMEM fuera rango", imem_write(uart, 4096, 0xDEADBEEF), 2
        )
        errors += check_read("IMEM read desalineada", imem_read(uart, 2), 1, 0)
        errors += check_read("IMEM read fuera rango", imem_read(uart, 4096), 2, 0)
        errors += check_read(
            "IMEM conserva word", imem_read(uart, 0), 0, 0x00100093
        )

        errors += check_write(
            "DMEM sw", dmem_write(uart, MEM_WORD, 0x100, 0x11223344), 0
        )
        errors += check_read(
            "DMEM lw", dmem_read(uart, MEM_WORD, False, 0x100), 0, 0x11223344
        )
        errors += check_write(
            "DMEM sb lane 1", dmem_write(uart, MEM_BYTE, 0x101, 0xAA), 0
        )
        errors += check_write(
            "DMEM sb negativo", dmem_write(uart, MEM_BYTE, 0x103, 0x80), 0
        )
        errors += check_read(
            "DMEM lanes little-endian",
            dmem_read(uart, MEM_WORD, False, 0x100),
            0,
            0x8022AA44,
        )
        errors += check_read(
            "DMEM lb", dmem_read(uart, MEM_BYTE, False, 0x103), 0, 0xFFFFFF80
        )
        errors += check_read(
            "DMEM lbu", dmem_read(uart, MEM_BYTE, True, 0x103), 0, 0x80
        )
        errors += check_write(
            "DMEM sh", dmem_write(uart, MEM_HALF, 0x102, 0xBEEF), 0
        )
        errors += check_read(
            "DMEM lh", dmem_read(uart, MEM_HALF, False, 0x102), 0, 0xFFFFBEEF
        )
        errors += check_read(
            "DMEM lhu", dmem_read(uart, MEM_HALF, True, 0x102), 0, 0xBEEF
        )
        errors += check_write(
            "DMEM byte final", dmem_write(uart, MEM_BYTE, 4095, 0x7F), 0
        )
        errors += check_read(
            "DMEM read byte final",
            dmem_read(uart, MEM_BYTE, False, 4095),
            0,
            0x7F,
        )
        errors += check_write(
            "DMEM half desalineada", dmem_write(uart, MEM_HALF, 0x101, 0x1234), 1
        )
        errors += check_read(
            "DMEM word desalineada",
            dmem_read(uart, MEM_WORD, False, 0x102),
            1,
            0,
        )
        errors += check_read(
            "DMEM fuera rango",
            dmem_read(uart, MEM_BYTE, False, 4096),
            2,
            0,
        )
        errors += check_write(
            "DMEM half limite", dmem_write(uart, MEM_HALF, 4095, 0x1234), 3
        )

    if errors:
        print(f"RESULTADO: MEMORIAS RV32 CON {errors} ERRORES")
        return 1

    print("RESULTADO: MEMORIAS RV32 EN PLACA OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
