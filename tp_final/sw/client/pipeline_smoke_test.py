"""Prueba en placa el forwarding y los stalls del pipeline RV32I."""

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
CMD_LOAD_WORD = 0x10
CMD_RUN = 0x20
CMD_STATUS = 0x21
CMD_READ_REG = 0x22
CMD_READ_DMEM = 0x23

MEM_WORD = 2

# Sin NOP: ejercita forwarding, flush de branch y tres stalls load-use.
PROGRAM = [
    0x00500093,  # addi x1,x0,5
    0x00708113,  # addi x2,x1,7          EX/MEM -> EX
    0x001101B3,  # add x3,x2,x1          EX/MEM y MEM/WB -> EX
    0x00302023,  # sw x3,0(x0)           forwarding a store
    0x00002203,  # lw x4,0(x0)
    0xFFE20293,  # addi x5,x4,-2         load-use: stall 1
    0x00428333,  # add x6,x5,x4
    0x02000393,  # addi x7,x0,32
    0x00730663,  # beq x6,x7,+12         forwarding a branch
    0x06300413,  # wrong path
    0x05800413,  # wrong path
    0x02A00413,  # addi x8,x0,42
    0x00802223,  # sw x8,4(x0)
    0x00402483,  # lw x9,4(x0)
    0x00902423,  # sw x9,8(x0)           load-use: stall 2
    0x00802503,  # lw x10,8(x0)
    0x00150593,  # addi x11,x10,1        load-use: stall 3
    0x00100073,  # ebreak
]


def read_exact(uart: serial.Serial, size: int) -> bytes:
    response = uart.read(size)
    if len(response) != size:
        raise TimeoutError(f"Respuesta incompleta: {len(response)}/{size} bytes")
    return response


def load_word(uart: serial.Serial, index: int, instruction: int) -> int:
    address = index * 4
    uart.write(
        bytes([CMD_LOAD_WORD])
        + address.to_bytes(4, "little")
        + instruction.to_bytes(4, "little")
    )
    uart.flush()
    return read_exact(uart, 1)[0]


def run_program(uart: serial.Serial, words: int) -> int:
    uart.write(bytes([CMD_RUN]) + words.to_bytes(4, "little"))
    uart.flush()
    return read_exact(uart, 1)[0]


def get_status(uart: serial.Serial) -> dict[str, int]:
    uart.write(bytes([CMD_STATUS]))
    uart.flush()
    data = read_exact(uart, 16)
    return {
        "running": data[0],
        "halted": data[1],
        "cause": data[2],
        "valid": data[3],
        "pc": int.from_bytes(data[4:8], "little"),
        "cycles": int.from_bytes(data[8:12], "little"),
        "retired": int.from_bytes(data[12:16], "little"),
    }


def read_register(uart: serial.Serial, address: int) -> tuple[int, int]:
    uart.write(bytes([CMD_READ_REG, address & 0xFF]))
    uart.flush()
    response = read_exact(uart, 5)
    return response[0], int.from_bytes(response[1:5], "little")


def read_dmem_word(uart: serial.Serial, address: int) -> tuple[int, int]:
    uart.write(
        bytes([CMD_READ_DMEM, MEM_WORD, 0])
        + address.to_bytes(4, "little")
    )
    uart.flush()
    response = read_exact(uart, 5)
    return response[0], int.from_bytes(response[1:5], "little")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("port", help="Puerto serie, por ejemplo COM7")
    args = parser.parse_args()

    errors = 0
    with serial.Serial(args.port, BAUD_RATE, timeout=2, write_timeout=2) as uart:
        time.sleep(0.2)
        uart.reset_input_buffer()
        uart.reset_output_buffer()

        for index, instruction in enumerate(PROGRAM):
            status = load_word(uart, index, instruction)
            if status != 0:
                errors += 1
                print(
                    f"ERROR LOAD word={index:02d} instr=0x{instruction:08X} "
                    f"status=0x{status:02X}"
                )
        if errors == 0:
            print(f"OK    Programa cargado: {len(PROGRAM)} palabras")

        run_status = run_program(uart, len(PROGRAM))
        if run_status != 0:
            print(f"ERROR RUN status=0x{run_status:02X}")
            errors += 1

        deadline = time.monotonic() + 2.0
        status = get_status(uart)
        while status["running"] and time.monotonic() < deadline:
            time.sleep(0.01)
            status = get_status(uart)

        status_ok = (
            status["running"] == 0
            and status["halted"] == 1
            and status["cause"] == 1
            and status["valid"] == 0
            and status["pc"] == 0x48
            and status["cycles"] == 25
            and status["retired"] == 15
        )
        print(
            f"{'OK' if status_ok else 'ERROR':5} STATUS "
            f"halted={status['halted']} cause={status['cause']} "
            f"valid=0x{status['valid']:X} pc=0x{status['pc']:08X} "
            f"ciclos={status['cycles']} retiradas={status['retired']}"
        )
        errors += 0 if status_ok else 1

        expected_registers = {
            0: 0,
            1: 5,
            2: 12,
            3: 17,
            4: 17,
            5: 15,
            6: 32,
            7: 32,
            8: 42,
            9: 42,
            10: 42,
            11: 43,
        }
        for address, expected in expected_registers.items():
            read_status_code, value = read_register(uart, address)
            ok = read_status_code == 0 and value == expected
            print(
                f"{'OK' if ok else 'ERROR':5} x{address:02d}=0x{value:08X}"
            )
            errors += 0 if ok else 1

        for address, expected in {0: 17, 4: 42, 8: 42}.items():
            dmem_status, dmem_value = read_dmem_word(uart, address)
            dmem_ok = dmem_status == 0 and dmem_value == expected
            print(
                f"{'OK' if dmem_ok else 'ERROR':5} "
                f"DMEM[{address}]=0x{dmem_value:08X}"
            )
            errors += 0 if dmem_ok else 1

    if errors:
        print(f"RESULTADO: PIPELINE RV32 EN PLACA CON {errors} ERRORES")
        return 1
    print("RESULTADO: PIPELINE RV32 HAZARDS EN PLACA OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
