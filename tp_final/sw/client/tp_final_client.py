"""Cliente reutilizable del protocolo UART incremental del TP final."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import BinaryIO

try:
    import serial
    from serial.tools import list_ports
except ModuleNotFoundError:  # Permite probar los parsers sin pyserial.
    serial = None
    list_ports = None


BAUD_RATE = 115_200

CMD_LOAD_WORD = 0x10
CMD_RUN = 0x20
CMD_STATUS = 0x21
CMD_READ_REG = 0x22
CMD_READ_DMEM = 0x23
CMD_START_PAUSED = 0x24
CMD_STEP = 0x25
CMD_PAUSE = 0x26
CMD_RESUME = 0x27
CMD_RESET_CORE = 0x28
CMD_SNAPSHOT = 0x29

STATUS_BUSY = 0x80
SNAPSHOT_MAGIC = 0x534E4150
SNAPSHOT_VERSION = 1
SNAPSHOT_WORD_COUNT = 32


class ProtocolError(RuntimeError):
    """Respuesta inválida o estado de error informado por la FPGA."""


@dataclass(frozen=True)
class ExecutionStatus:
    active: bool
    halted: bool
    paused: bool
    cause: int
    valid: int
    pc: int
    cycles: int
    retired: int


@dataclass(frozen=True)
class PipelineSnapshot:
    words: tuple[int, ...]

    @classmethod
    def from_bytes(cls, payload: bytes) -> "PipelineSnapshot":
        expected = SNAPSHOT_WORD_COUNT * 4
        if len(payload) != expected:
            raise ProtocolError(
                f"Snapshot incompleto: {len(payload)}/{expected} bytes"
            )
        words = tuple(
            int.from_bytes(payload[index : index + 4], "little")
            for index in range(0, expected, 4)
        )
        if words[0] != SNAPSHOT_MAGIC:
            raise ProtocolError(f"Magic de snapshot inválido: 0x{words[0]:08X}")
        version = words[1] & 0xFF
        word_count = (words[1] >> 8) & 0xFF
        if version != SNAPSHOT_VERSION or word_count != SNAPSHOT_WORD_COUNT:
            raise ProtocolError(
                f"Formato de snapshot no soportado: versión={version}, "
                f"palabras={word_count}"
            )
        return cls(words)

    @property
    def version(self) -> int:
        return self.words[1] & 0xFF

    @property
    def flags(self) -> int:
        return self.words[2]

    @property
    def pc(self) -> int:
        return self.words[3]

    @property
    def cycles(self) -> int:
        return self.words[4]

    @property
    def retired(self) -> int:
        return self.words[5]

    def stage(self, name: str) -> dict[str, int]:
        if name == "IF/ID":
            return {
                "valid": self.words[6] & 1,
                "pc": self.words[7],
                "instruction": self.words[8],
            }
        if name == "ID/EX":
            regs = self.words[15]
            return {
                "valid": self.words[9] & 1,
                "pc": self.words[10],
                "instruction": self.words[11],
                "rs1_data": self.words[12],
                "rs2_data": self.words[13],
                "immediate": self.words[14],
                "rs1": regs & 0x1F,
                "rs2": (regs >> 8) & 0x1F,
                "rd": (regs >> 16) & 0x1F,
                "control": self.words[16],
            }
        if name == "EX/MEM":
            control = self.words[23]
            return {
                "valid": self.words[17] & 1,
                "pc": self.words[18],
                "instruction": self.words[19],
                "alu": self.words[20],
                "store": self.words[21],
                "pc4": self.words[22],
                "rd": (control >> 8) & 0x1F,
                "control": control,
            }
        if name == "MEM/WB":
            control = self.words[30]
            return {
                "valid": self.words[24] & 1,
                "pc": self.words[25],
                "instruction": self.words[26],
                "alu": self.words[27],
                "memory": self.words[28],
                "pc4": self.words[29],
                "rd": (control >> 3) & 0x1F,
                "control": control,
                "writeback": self.words[31],
            }
        raise KeyError(f"Etapa desconocida: {name}")


def available_ports() -> list[str]:
    if list_ports is None:
        return []
    return [port.device for port in list_ports.comports()]


def load_program_file(path: str | Path) -> list[int]:
    program_path = Path(path)
    if program_path.suffix.lower() in (".asm", ".s"):
        from rv32i_assembler import assemble_file

        return list(assemble_file(program_path).words)
    if program_path.suffix.lower() == ".bin":
        data = program_path.read_bytes()
        if len(data) % 4:
            raise ValueError("El archivo binario no tiene un múltiplo de 4 bytes")
        return [
            int.from_bytes(data[index : index + 4], "little")
            for index in range(0, len(data), 4)
        ]

    words: list[int] = []
    for line_number, line in enumerate(
        program_path.read_text(encoding="utf-8").splitlines(), start=1
    ):
        clean = line
        for marker in ("//", "#", ";"):
            clean = clean.split(marker, 1)[0]
        for token in clean.replace(",", " ").split():
            try:
                value = int(token, 0) if token.lower().startswith("0x") else int(token, 16)
            except ValueError as exc:
                raise ValueError(
                    f"Palabra hexadecimal inválida en línea {line_number}: {token}"
                ) from exc
            if not 0 <= value <= 0xFFFF_FFFF:
                raise ValueError(f"Palabra fuera de 32 bits en línea {line_number}")
            words.append(value)
    if not words:
        raise ValueError("El archivo no contiene instrucciones")
    return words


class TpFinalClient:
    """Operaciones síncronas; la GUI las ejecuta dentro de un QThread."""

    def __init__(self, uart: BinaryIO):
        self.uart = uart

    @classmethod
    def open(cls, port: str, timeout: float = 2.0) -> "TpFinalClient":
        if serial is None:
            raise RuntimeError("Falta pyserial: py -m pip install pyserial")
        uart = serial.Serial(
            port, BAUD_RATE, timeout=timeout, write_timeout=timeout
        )
        uart.reset_input_buffer()
        uart.reset_output_buffer()
        return cls(uart)

    def close(self) -> None:
        self.uart.close()

    def _read_exact(self, size: int) -> bytes:
        data = bytearray()
        while len(data) < size:
            chunk = self.uart.read(size - len(data))
            if not chunk:
                raise TimeoutError(
                    f"Respuesta UART incompleta: {len(data)}/{size} bytes"
                )
            data.extend(chunk)
        return bytes(data)

    def _exchange(self, request: bytes, response_size: int) -> bytes:
        self.uart.write(request)
        self.uart.flush()
        return self._read_exact(response_size)

    def load_word(self, index: int, instruction: int) -> None:
        address = index * 4
        response = self._exchange(
            bytes([CMD_LOAD_WORD])
            + address.to_bytes(4, "little")
            + (instruction & 0xFFFF_FFFF).to_bytes(4, "little"),
            1,
        )[0]
        if response:
            raise ProtocolError(
                f"LOAD_WORD {index} rechazado con status 0x{response:02X}"
            )

    def load_program(self, words: list[int]) -> None:
        if not 0 < len(words) <= 1024:
            raise ValueError("El programa debe contener entre 1 y 1024 palabras")
        for index, instruction in enumerate(words):
            self.load_word(index, instruction)

    def _program_command(self, command: int, words: int) -> None:
        response = self._exchange(
            bytes([command]) + words.to_bytes(4, "little"), 1
        )[0]
        if response:
            raise ProtocolError(
                f"Comando 0x{command:02X} rechazado con status 0x{response:02X}"
            )

    def run(self, words: int) -> None:
        self._program_command(CMD_RUN, words)

    def start_paused(self, words: int) -> None:
        self._program_command(CMD_START_PAUSED, words)

    def _control(self, command: int) -> None:
        response = self._exchange(bytes([command]), 1)[0]
        if response:
            raise ProtocolError(
                f"Comando 0x{command:02X} rechazado con status 0x{response:02X}"
            )

    def step(self) -> None:
        self._control(CMD_STEP)

    def pause(self) -> None:
        self._control(CMD_PAUSE)

    def resume(self) -> None:
        self._control(CMD_RESUME)

    def reset_core(self) -> None:
        self._control(CMD_RESET_CORE)

    def status(self) -> ExecutionStatus:
        data = self._exchange(bytes([CMD_STATUS]), 16)
        return ExecutionStatus(
            active=bool(data[0] & 1),
            halted=bool(data[1] & 1),
            paused=bool(data[1] & 2),
            cause=data[2] & 0x0F,
            valid=data[3] & 0x0F,
            pc=int.from_bytes(data[4:8], "little"),
            cycles=int.from_bytes(data[8:12], "little"),
            retired=int.from_bytes(data[12:16], "little"),
        )

    def read_register(self, address: int) -> int:
        if not 0 <= address < 32:
            raise ValueError("Registro fuera de rango")
        response = self._exchange(bytes([CMD_READ_REG, address]), 5)
        if response[0]:
            raise ProtocolError(
                f"READ_REG rechazado con status 0x{response[0]:02X}"
            )
        return int.from_bytes(response[1:5], "little")

    def read_registers(self) -> list[int]:
        return [self.read_register(address) for address in range(32)]

    def read_dmem_word(self, address: int) -> int:
        response = self._exchange(
            bytes([CMD_READ_DMEM, 2, 0]) + address.to_bytes(4, "little"), 5
        )
        if response[0]:
            raise ProtocolError(
                f"READ_DMEM rechazado con status 0x{response[0]:02X}"
            )
        return int.from_bytes(response[1:5], "little")

    def read_dmem_words(self, first_address: int, count: int) -> list[int]:
        return [
            self.read_dmem_word(first_address + index * 4)
            for index in range(count)
        ]

    def snapshot(self) -> PipelineSnapshot:
        self.uart.write(bytes([CMD_SNAPSHOT]))
        self.uart.flush()
        status = self._read_exact(1)[0]
        if status:
            raise ProtocolError(
                f"SNAPSHOT rechazado con status 0x{status:02X}"
            )
        return PipelineSnapshot.from_bytes(
            self._read_exact(SNAPSHOT_WORD_COUNT * 4)
        )
