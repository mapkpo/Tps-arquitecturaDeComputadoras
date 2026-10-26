import ast
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "sw" / "client"))
from rv32i_assembler import AssemblyError, assemble, assemble_file
from tp_final_client import load_program_file


class AssemblerTests(unittest.TestCase):
    def test_all_required_instructions_match_validated_image(self):
        tree = ast.parse((ROOT / "sw/client/rv32i_coverage_test.py").read_text(encoding="utf-8"))
        expected = next(ast.literal_eval(node.value) for node in tree.body
                        if isinstance(node, ast.Assign) and any(isinstance(t, ast.Name) and t.id == "PROGRAM" for t in node.targets))
        actual = assemble_file(ROOT / "sim/programs/rv32i_coverage.S")
        self.assertEqual(list(actual.words), expected)
        self.assertEqual(len(actual.words), 52)

    def test_demo_matches_existing_hex(self):
        self.assertEqual(load_program_file(ROOT / "sw/programs/pipeline_demo.asm"),
                         load_program_file(ROOT / "sw/programs/pipeline_demo.hex"))

    def test_labels_comments_aliases_and_pseudos(self):
        result = assemble("""# comentario
start: addi ra, zero, -1
       beq ra, sp, end ; adelante
       jal ra, start // atras
end:   nop
       .word 0xffffffff
       halt
""")
        self.assertEqual(result.labels, {"start": 0, "end": 12})
        self.assertEqual(result.words, (0xFFF00093, 0x00208463, 0xFF9FF0EF, 0x13, 0xFFFFFFFF, 0x00100073))
        self.assertEqual(assemble("jalr ra, sp, -4\nhalt").words,
                         assemble("jalr x1, -4(x2)\nebreak").words)

    def test_negative_and_boundary_encodings(self):
        cases = {
            "beq x1,x2,-4": 0xFE208EE3,
            "jal x1,-4": 0xFFDFF0EF,
            "sw x1,-4(x2)": 0xFE112E23,
            "addi x1,x0,-2048": 0x80000093,
            "addi x1,x0,2047": 0x7FF00093,
            "srai x1,x2,31": 0x41F15093,
            "lui x1,0xfffff": 0xFFFFF0B7,
        }
        for source, expected in cases.items():
            with self.subTest(source=source):
                self.assertEqual(assemble(source + "\nhalt").words[0], expected)

    def test_rejects_invalid_source(self):
        cases = ["add x32,x0,x0", "addi x1,x0,2048", "addi x1,x0,-2049",
                 "slli x1,x0,32", "srai x1,x0,-1", "lw x1,4096(x0)",
                 "lui x1,0x100000", "beq x0,x0,2", "beq x0,x0,4096",
                 "jal x1,1048576", "jal x1,missing", "add x1,x2",
                 "add x1 x2 x3", "lw x1,(x0)", "nop x1", ".word 0x100000000",
                 "auipc x1,0", "here: nop\nhere: nop"]
        for source in cases:
            with self.subTest(source=source), self.assertRaisesRegex(AssemblyError, "Linea"):
                assemble(source + "\nhalt")
        for source in ("", "# vacio", "addi x1,x0,1", "nop\n" * 1024 + "halt"):
            with self.subTest(source=source[:30]), self.assertRaises(AssemblyError):
                assemble(source)
        self.assertEqual(len(assemble("nop\n" * 1023 + "halt").words), 1024)

    def test_cli_outputs_and_errors(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "demo.asm"
            source.write_text("start: addi x1,x0,1\nhalt", encoding="utf-8")
            command = [sys.executable, "-B", str(ROOT / "sw/client/rv32i_assembler.py"), str(source)]
            run = subprocess.run(command, capture_output=True, text=True)
            self.assertEqual(run.returncode, 0, run.stderr)
            self.assertEqual(load_program_file(source.with_suffix(".hex")), [0x00100093, 0x00100073])
            self.assertEqual(load_program_file(source.with_suffix(".bin")), [0x00100093, 0x00100073])
            self.assertIn("00000000 start", source.with_suffix(".map").read_text())
            source.write_text("bad x1\nhalt", encoding="utf-8")
            run = subprocess.run(command, capture_output=True, text=True)
            self.assertNotEqual(run.returncode, 0)
            self.assertIn("Linea 1", run.stderr)


class GuiAssemblerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
        sys.path.insert(0, str(ROOT / "sw/gui"))
        import tp_final_gui
        cls.gui = tp_final_gui
        cls.app = tp_final_gui.QApplication.instance() or tp_final_gui.QApplication([])

    def test_gui_assembles_before_sending_and_rejects_errors(self):
        with patch.object(self.gui, "available_ports", return_value=[]):
            window = self.gui.MainWindow()
        try:
            window.file_edit.setText(str(ROOT / "sw/programs/pipeline_demo.asm"))
            with patch.object(window, "submit") as submit:
                window.load_program()
                submit.assert_called_once_with("load", [0x00100093, 0x00208113, 0x00202023, 0x00100073])
            self.assertIn("Ensamblado OK", window.log_view.toPlainText())
            with tempfile.TemporaryDirectory() as directory:
                bad = Path(directory) / "bad.asm"
                bad.write_text("addi x1,x0,9999\nhalt")
                window.file_edit.setText(str(bad))
                with patch.object(window, "submit") as submit, patch.object(self.gui.QMessageBox, "critical") as error:
                    window.load_program()
                    submit.assert_not_called()
                    self.assertIn("Linea 1", error.call_args.args[2])
        finally:
            window.close()


if __name__ == "__main__":
    unittest.main()
