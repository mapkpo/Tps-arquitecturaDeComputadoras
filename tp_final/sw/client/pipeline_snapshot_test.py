"""Valida y muestra el snapshot completo del pipeline RV32I en la Basys 3."""

from __future__ import annotations

import argparse
import sys
import time

from execution_control_test import (
    CMD_RESET_CORE,
    CMD_STEP,
    SHORT_PROGRAM,
    control,
    start_paused,
)
from pipeline_smoke_test import BAUD_RATE, load_word, read_exact, serial


CMD_SNAPSHOT = 0x29
SNAPSHOT_WORDS = 32


def read_snapshot(uart: serial.Serial) -> tuple[int, list[int]]:
    uart.write(bytes([CMD_SNAPSHOT]))
    uart.flush()
    status = read_exact(uart, 1)[0]
    if status != 0:
        return status, []
    payload = read_exact(uart, SNAPSHOT_WORDS * 4)
    words = [
        int.from_bytes(payload[index : index + 4], "little")
        for index in range(0, len(payload), 4)
    ]
    return status, words


def print_stage(name: str, valid: int, pc: int, instruction: int) -> None:
    print(
        f"OK    {name:<7} valid={valid & 1} "
        f"pc=0x{pc:08X} instr=0x{instruction:08X}"
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("port", help="Puerto serie, por ejemplo COM7")
    args = parser.parse_args()
    errors = 0

    with serial.Serial(args.port, BAUD_RATE, timeout=2, write_timeout=2) as uart:
        time.sleep(0.2)
        uart.reset_input_buffer()
        uart.reset_output_buffer()

        if control(uart, CMD_RESET_CORE) != 0:
            print("ERROR RESET_CORE inicial")
            return 1

        for index, instruction in enumerate(SHORT_PROGRAM):
            if load_word(uart, index, instruction) != 0:
                print(f"ERROR LOAD word={index}")
                return 1

        if start_paused(uart, len(SHORT_PROGRAM)) != 0:
            print("ERROR START_PAUSED")
            return 1

        for step in range(4):
            status = control(uart, CMD_STEP)
            if status != 0:
                print(f"ERROR STEP {step + 1} status=0x{status:02X}")
                return 1

        status, words = read_snapshot(uart)
        if status != 0:
            print(f"ERROR SNAPSHOT status=0x{status:02X}")
            return 1

        global_expected = {
            0: 0x534E4150,
            1: 0x00002001,
            2: 0x000000F1,
            3: 16,
            4: 4,
            5: 0,
        }
        for index, expected in global_expected.items():
            if words[index] != expected:
                errors += 1
                print(
                    f"ERROR word[{index}] 0x{words[index]:08X} "
                    f"esperado=0x{expected:08X}"
                )

        print(
            f"{'OK' if errors == 0 else 'ERROR':5} HEADER magic=0x{words[0]:08X} "
            f"version={words[1] & 0xFF} words={(words[1] >> 8) & 0xFF}"
        )
        print(
            f"OK    GLOBAL  pc=0x{words[3]:08X} ciclos={words[4]} "
            f"retiradas={words[5]} valid=0x{(words[2] >> 4) & 0xF:X}"
        )
        print_stage("IF/ID", words[6], words[7], words[8])
        print_stage("ID/EX", words[9], words[10], words[11])
        print(
            f"      rs1_data=0x{words[12]:08X} rs2_data=0x{words[13]:08X} "
            f"imm=0x{words[14]:08X} regs=0x{words[15]:08X} "
            f"control=0x{words[16]:08X}"
        )
        print_stage("EX/MEM", words[17], words[18], words[19])
        print(
            f"      alu=0x{words[20]:08X} store=0x{words[21]:08X} "
            f"pc4=0x{words[22]:08X} control=0x{words[23]:08X}"
        )
        print_stage("MEM/WB", words[24], words[25], words[26])
        print(
            f"      alu=0x{words[27]:08X} mem=0x{words[28]:08X} "
            f"pc4=0x{words[29]:08X} control=0x{words[30]:08X} "
            f"wb=0x{words[31]:08X}"
        )

        expected_words = {
            6: 1,
            7: 12,
            8: 0x00100073,
            9: 1,
            10: 8,
            11: 0x00202023,
            12: 0,
            13: 0,
            14: 0,
            15: 0x00000200,
            16: 0x00000282,
            17: 1,
            18: 4,
            19: 0x00208113,
            20: 3,
            21: 0,
            22: 8,
            23: 0x00000211,
            24: 1,
            25: 0,
            26: 0x00100093,
            27: 1,
            29: 4,
            30: 0x00000009,
            31: 1,
        }
        for index, expected in expected_words.items():
            if words[index] != expected:
                errors += 1
                print(
                    f"ERROR word[{index}] 0x{words[index]:08X} "
                    f"esperado=0x{expected:08X}"
                )

        reset_status = control(uart, CMD_RESET_CORE)
        if reset_status != 0:
            errors += 1
            print(f"ERROR RESET final status=0x{reset_status:02X}")

    if errors:
        print(f"RESULTADO: SNAPSHOT DEL PIPELINE CON {errors} ERRORES")
        return 1
    print("RESULTADO: SNAPSHOT COMPLETO DEL PIPELINE EN PLACA OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
