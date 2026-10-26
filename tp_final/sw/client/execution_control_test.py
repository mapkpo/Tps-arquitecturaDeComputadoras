"""Prueba RUN, STEP, PAUSE, RESUME y RESET_CORE en la Basys 3."""

from __future__ import annotations

import argparse
import sys
import time

from pipeline_smoke_test import (
    BAUD_RATE,
    CMD_STATUS,
    load_word,
    read_dmem_word,
    read_exact,
    read_register,
    run_program,
    serial,
)


CMD_START_PAUSED = 0x24
CMD_STEP = 0x25
CMD_PAUSE = 0x26
CMD_RESUME = 0x27
CMD_RESET_CORE = 0x28

SHORT_PROGRAM = [
    0x00100093,  # addi x1,x0,1
    0x00208113,  # addi x2,x1,2
    0x00202023,  # sw x2,0(x0)
    0x00100073,  # ebreak
]

LOOP_PROGRAM = [
    0x00108093,  # addi x1,x1,1
    0xFFDFF06F,  # jal x0,-4
    0x00000013,  # camino especulativo
    0x00000013,  # camino especulativo
]


def control(uart: serial.Serial, command: int) -> int:
    uart.write(bytes([command]))
    uart.flush()
    return read_exact(uart, 1)[0]


def start_paused(uart: serial.Serial, words: int) -> int:
    uart.write(bytes([CMD_START_PAUSED]) + words.to_bytes(4, "little"))
    uart.flush()
    return read_exact(uart, 1)[0]


def get_execution_status(uart: serial.Serial) -> dict[str, int]:
    uart.write(bytes([CMD_STATUS]))
    uart.flush()
    data = read_exact(uart, 16)
    return {
        "active": data[0] & 1,
        "halted": data[1] & 1,
        "paused": (data[1] >> 1) & 1,
        "cause": data[2] & 0x0F,
        "valid": data[3] & 0x0F,
        "pc": int.from_bytes(data[4:8], "little"),
        "cycles": int.from_bytes(data[8:12], "little"),
        "retired": int.from_bytes(data[12:16], "little"),
    }


def print_status(label: str, status: dict[str, int], ok: bool) -> None:
    print(
        f"{'OK' if ok else 'ERROR':5} {label:<14} "
        f"active={status['active']} paused={status['paused']} "
        f"halted={status['halted']} pc=0x{status['pc']:08X} "
        f"ciclos={status['cycles']} retiradas={status['retired']} "
        f"valid=0x{status['valid']:X}"
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

        reset_status = control(uart, CMD_RESET_CORE)
        if reset_status != 0:
            errors += 1
            print(f"ERROR RESET inicial status=0x{reset_status:02X}")

        for index, instruction in enumerate(SHORT_PROGRAM):
            if load_word(uart, index, instruction) != 0:
                errors += 1
                print(f"ERROR LOAD programa corto word={index}")

        start_status = start_paused(uart, len(SHORT_PROGRAM))
        status = get_execution_status(uart)
        initial_ok = (
            start_status == 0
            and status["active"] == 0
            and status["paused"] == 1
            and status["halted"] == 0
            and status["pc"] == 0
            and status["cycles"] == 0
        )
        print_status("START_PAUSED", status, initial_ok)
        errors += 0 if initial_ok else 1

        steps = 0
        while not status["halted"] and steps < 20:
            previous_cycles = status["cycles"]
            step_status = control(uart, CMD_STEP)
            status = get_execution_status(uart)
            ok = step_status == 0 and status["cycles"] == previous_cycles + 1
            print_status(f"STEP {steps + 1}", status, ok)
            errors += 0 if ok else 1
            steps += 1

        final_step_ok = (
            status["halted"] == 1
            and status["cause"] == 1
            and status["valid"] == 0
            and status["pc"] == 0x10
            and status["cycles"] == 8
            and status["retired"] == 3
        )
        print_status("HALT por STEP", status, final_step_ok)
        errors += 0 if final_step_ok else 1

        for address, expected in {1: 1, 2: 3}.items():
            read_status_code, value = read_register(uart, address)
            ok = read_status_code == 0 and value == expected
            print(f"{'OK' if ok else 'ERROR':5} x{address:02d}=0x{value:08X}")
            errors += 0 if ok else 1
        dmem_status, dmem_value = read_dmem_word(uart, 0)
        dmem_ok = dmem_status == 0 and dmem_value == 3
        print(f"{'OK' if dmem_ok else 'ERROR':5} DMEM[0]=0x{dmem_value:08X}")
        errors += 0 if dmem_ok else 1

        rejected_step = control(uart, CMD_STEP)
        rejected_ok = rejected_step == 0x80
        print(
            f"{'OK' if rejected_ok else 'ERROR':5} "
            f"STEP detenido status=0x{rejected_step:02X}"
        )
        errors += 0 if rejected_ok else 1

        control(uart, CMD_RESET_CORE)
        reg_status, reg_value = read_register(uart, 1)
        reset_reg_ok = reg_status == 0 and reg_value == 0
        print(f"{'OK' if reset_reg_ok else 'ERROR':5} RESET x01=0x{reg_value:08X}")
        errors += 0 if reset_reg_ok else 1

        for index, instruction in enumerate(LOOP_PROGRAM):
            if load_word(uart, index, instruction) != 0:
                errors += 1
                print(f"ERROR LOAD loop word={index}")

        run_status = run_program(uart, len(LOOP_PROGRAM))
        time.sleep(0.02)
        pause_status = control(uart, CMD_PAUSE)
        paused = get_execution_status(uart)
        paused_ok = (
            run_status == 0
            and pause_status == 0
            and paused["active"] == 0
            and paused["paused"] == 1
            and paused["halted"] == 0
        )
        print_status("PAUSE", paused, paused_ok)
        errors += 0 if paused_ok else 1

        frozen_cycles = paused["cycles"]
        time.sleep(0.02)
        still_paused = get_execution_status(uart)
        frozen_ok = still_paused["cycles"] == frozen_cycles
        print_status("PAUSE estable", still_paused, frozen_ok)
        errors += 0 if frozen_ok else 1

        step_status = control(uart, CMD_STEP)
        after_step = get_execution_status(uart)
        one_step_ok = step_status == 0 and after_step["cycles"] == frozen_cycles + 1
        print_status("STEP pausado", after_step, one_step_ok)
        errors += 0 if one_step_ok else 1

        resume_status = control(uart, CMD_RESUME)
        time.sleep(0.02)
        pause_again_status = control(uart, CMD_PAUSE)
        resumed = get_execution_status(uart)
        resume_ok = (
            resume_status == 0
            and pause_again_status == 0
            and resumed["paused"] == 1
            and resumed["cycles"] > after_step["cycles"]
        )
        print_status("RESUME/PAUSE", resumed, resume_ok)
        errors += 0 if resume_ok else 1

        final_reset_status = control(uart, CMD_RESET_CORE)
        reset = get_execution_status(uart)
        reset_ok = (
            final_reset_status == 0
            and reset["active"] == 0
            and reset["paused"] == 0
            and reset["halted"] == 0
            and reset["pc"] == 0
            and reset["cycles"] == 0
            and reset["valid"] == 0
        )
        print_status("RESET_CORE", reset, reset_ok)
        errors += 0 if reset_ok else 1

    if errors:
        print(f"RESULTADO: CONTROL DE EJECUCION CON {errors} ERRORES")
        return 1
    print("RESULTADO: RUN STEP PAUSE RESUME RESET EN PLACA OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
