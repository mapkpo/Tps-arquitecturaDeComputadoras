"""Valida en placa las 32 instrucciones RV32I exigidas por el TP."""

from __future__ import annotations

import argparse
import sys
import time

from pipeline_smoke_test import (
    BAUD_RATE,
    get_status,
    load_word,
    read_dmem_word,
    read_register,
    run_program,
    serial,
)


PROGRAM = [
    0x00500093, 0xFF800113, 0x002081B3, 0x40208233,
    0x001092B3, 0x00115333, 0x401153B3, 0x0020F433,
    0x0020E4B3, 0x0020C533, 0x001125B3, 0x00113633,
    0x00F4F693, 0x05546713, 0x0FF74793, 0x00012813,
    0x0060B893, 0x00309913, 0x00215993, 0x40215A13,
    0xABCDEAB7, 0xF8000B13, 0x01502023, 0x016000A3,
    0x00F01123, 0x00100B83, 0x00104C03, 0x00201C83,
    0x00205D03, 0x00002D83, 0x016B8663, 0x06300E13,
    0x05800E13, 0x00100E13, 0x00209663, 0x04D00E13,
    0x04200E13, 0x001E0E13, 0x00208463, 0x001E0E13,
    0x00109463, 0x001E0E13, 0x00C00EEF, 0x03700E13,
    0x03800E13, 0x001E0E13, 0x0C800F13, 0x000F0FE7,
    0x02C00E13, 0x02D00E13, 0x001E0E13, 0x00100073,
]

EXPECTED_REGISTERS = [
    0x00000000, 0x00000005, 0xFFFFFFF8, 0xFFFFFFFD,
    0x0000000D, 0x000000A0, 0x07FFFFFF, 0xFFFFFFFF,
    0x00000000, 0xFFFFFFFD, 0xFFFFFFFD, 0x00000001,
    0x00000000, 0x0000000D, 0x00000055, 0x000000AA,
    0x00000001, 0x00000001, 0x00000028, 0x3FFFFFFE,
    0xFFFFFFFE, 0xABCDE000, 0xFFFFFF80, 0xFFFFFF80,
    0x00000080, 0x000000AA, 0x000000AA, 0x00AA8000,
    0x00000006, 0x000000AC, 0x000000C8, 0x000000C0,
]


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
            errors += 1
            print(f"ERROR RUN status=0x{run_status:02X}")

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
            and status["pc"] == 0xD0
            and status["cycles"] == 56
            and status["retired"] == 43
        )
        print(
            f"{'OK' if status_ok else 'ERROR':5} STATUS "
            f"halted={status['halted']} cause={status['cause']} "
            f"valid=0x{status['valid']:X} pc=0x{status['pc']:08X} "
            f"ciclos={status['cycles']} retiradas={status['retired']}"
        )
        errors += 0 if status_ok else 1

        for address, expected in enumerate(EXPECTED_REGISTERS):
            read_status_code, value = read_register(uart, address)
            ok = read_status_code == 0 and value == expected
            print(f"{'OK' if ok else 'ERROR':5} x{address:02d}=0x{value:08X}")
            errors += 0 if ok else 1

        dmem_status, dmem_value = read_dmem_word(uart, 0)
        dmem_ok = dmem_status == 0 and dmem_value == 0x00AA8000
        print(f"{'OK' if dmem_ok else 'ERROR':5} DMEM[0]=0x{dmem_value:08X}")
        errors += 0 if dmem_ok else 1

    if errors:
        print(f"RESULTADO: COBERTURA RV32I EN PLACA CON {errors} ERRORES")
        return 1
    print("RESULTADO: COBERTURA RV32I COMPLETA EN PLACA OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
