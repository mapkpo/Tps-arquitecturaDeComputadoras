from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

CLIENT_DIR = Path(__file__).resolve().parents[1] / "client"
sys.path.insert(0, str(CLIENT_DIR))

from rv32i_disassembler import disassemble
from tp_final_client import (
    SNAPSHOT_MAGIC,
    PipelineSnapshot,
    ProtocolError,
    load_program_file,
)


class SnapshotTests(unittest.TestCase):
    def setUp(self) -> None:
        self.words = [0] * 32
        self.words[0] = SNAPSHOT_MAGIC
        self.words[1] = 0x00002001
        self.words[2] = 0x000000F1
        self.words[3] = 16
        self.words[4] = 4
        self.words[6:9] = [1, 12, 0x00100073]
        self.words[9:17] = [
            1, 8, 0x00202023, 0, 0, 0, 0x00000200, 0x00000282
        ]
        self.words[17:24] = [
            1, 4, 0x00208113, 3, 0, 8, 0x00000211
        ]
        self.words[24:32] = [
            1, 0, 0x00100093, 1, 0, 4, 0x00000009, 1
        ]

    def payload(self) -> bytes:
        return b"".join(word.to_bytes(4, "little") for word in self.words)

    def test_decodes_all_pipeline_stages(self) -> None:
        snapshot = PipelineSnapshot.from_bytes(self.payload())
        self.assertEqual(snapshot.version, 1)
        self.assertEqual(snapshot.pc, 16)
        self.assertEqual(snapshot.stage("IF/ID")["instruction"], 0x00100073)
        self.assertEqual(snapshot.stage("ID/EX")["rs2"], 2)
        self.assertEqual(snapshot.stage("EX/MEM")["alu"], 3)
        self.assertEqual(snapshot.stage("MEM/WB")["writeback"], 1)

    def test_rejects_bad_magic(self) -> None:
        self.words[0] = 0
        with self.assertRaises(ProtocolError):
            PipelineSnapshot.from_bytes(self.payload())

    def test_rejects_incomplete_payload(self) -> None:
        with self.assertRaises(ProtocolError):
            PipelineSnapshot.from_bytes(self.payload()[:-1])


class ProgramAndDisassemblerTests(unittest.TestCase):
    def test_loads_hex_and_binary_programs(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            hex_path = root / "program.hex"
            hex_path.write_text(
                "00100093  # addi\n00208113\n00100073\n", encoding="utf-8"
            )
            bin_path = root / "program.bin"
            bin_path.write_bytes(
                b"".join(
                    word.to_bytes(4, "little")
                    for word in (0x00100093, 0x00100073)
                )
            )
            self.assertEqual(
                load_program_file(hex_path),
                [0x00100093, 0x00208113, 0x00100073],
            )
            self.assertEqual(
                load_program_file(bin_path), [0x00100093, 0x00100073]
            )

    def test_disassembles_required_examples(self) -> None:
        self.assertTrue(disassemble(0x00100093).startswith("addi x1"))
        self.assertTrue(disassemble(0x00202023).startswith("sw x2"))
        self.assertEqual(disassemble(0x00100073), "ebreak")


if __name__ == "__main__":
    unittest.main()
