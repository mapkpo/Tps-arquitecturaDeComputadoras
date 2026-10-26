"""Interfaz gráfica incremental para controlar y observar el pipeline RV32I."""

from __future__ import annotations

import json
import sys
from pathlib import Path

CLIENT_DIR = Path(__file__).resolve().parents[1] / "client"
if str(CLIENT_DIR) not in sys.path:
    sys.path.insert(0, str(CLIENT_DIR))

try:
    from PySide6.QtCore import QObject, QThread, QTimer, Signal, Slot
    from PySide6.QtGui import QCloseEvent, QFont
    from PySide6.QtWidgets import (
        QApplication,
        QComboBox,
        QFileDialog,
        QGridLayout,
        QGroupBox,
        QHBoxLayout,
        QLabel,
        QLineEdit,
        QMainWindow,
        QMessageBox,
        QPushButton,
        QPlainTextEdit,
        QSplitter,
        QTableWidget,
        QTableWidgetItem,
        QTabWidget,
        QVBoxLayout,
        QWidget,
    )
except ModuleNotFoundError:
    print("Falta PySide6. Instalalo con: py -m pip install PySide6")
    raise SystemExit(1)

from rv32i_disassembler import ABI, disassemble
from tp_final_client import (
    ExecutionStatus,
    PipelineSnapshot,
    TpFinalClient,
    available_ports,
    load_program_file,
)


CAUSES = {
    0: "Sin causa",
    1: "HALT / EBREAK",
    2: "Instrucción ilegal",
    3: "PC fuera del programa",
    4: "Fallo de IMEM",
    5: "DMEM desalineada",
    6: "DMEM fuera de rango",
}


class SerialWorker(QObject):
    result = Signal(str, object)
    error = Signal(str, str, bool)

    def __init__(self) -> None:
        super().__init__()
        self.client: TpFinalClient | None = None

    @Slot(str, object)
    def execute(self, operation: str, payload: object) -> None:
        try:
            if operation == "connect":
                if self.client is not None:
                    self.client.close()
                self.client = TpFinalClient.open(str(payload))
                self.result.emit(operation, self.client.status())
                return
            if operation == "disconnect":
                if self.client is not None:
                    self.client.close()
                    self.client = None
                self.result.emit(operation, None)
                return
            if self.client is None:
                raise RuntimeError("No hay una conexión UART abierta")

            if operation == "load":
                words = list(payload)
                self.client.reset_core()
                self.client.load_program(words)
                self.client.start_paused(len(words))
                self.result.emit(operation, self.client.status())
            elif operation == "run":
                status = self.client.status()
                if status.paused:
                    self.client.resume()
                else:
                    self.client.run(int(payload))
                self.result.emit(operation, self.client.status())
            elif operation == "step":
                self.client.step()
                self.result.emit(operation, self.client.status())
            elif operation == "pause":
                self.client.pause()
                self.result.emit(operation, self.client.status())
            elif operation == "resume":
                self.client.resume()
                self.result.emit(operation, self.client.status())
            elif operation == "reset":
                self.client.reset_core()
                self.result.emit(operation, self.client.status())
            elif operation == "status":
                self.result.emit(operation, self.client.status())
            elif operation == "inspect":
                status = self.client.status()
                data: dict[str, object] = {"status": status}
                if not status.active:
                    data["snapshot"] = self.client.snapshot()
                    data["registers"] = self.client.read_registers()
                    data["memory"] = self.client.read_dmem_words(0, 16)
                self.result.emit(operation, data)
            else:
                raise ValueError(f"Operación desconocida: {operation}")
        except Exception as exc:  # El error vuelve al hilo de la interfaz.
            connection_lost = isinstance(exc, (OSError, TimeoutError)) or operation == "connect"
            if connection_lost and self.client is not None:
                client, self.client = self.client, None
                try:
                    client.close()
                except Exception:
                    pass  # Conservar el error original si el dispositivo desapareció.
            self.error.emit(operation, str(exc), connection_lost)


class MainWindow(QMainWindow):
    request = Signal(str, object)

    def __init__(self) -> None:
        super().__init__()
        self.setWindowTitle("TP final — Pipeline RV32I / Basys 3")
        self.resize(1320, 850)

        self.connected = False
        self.busy = False
        self.program_words: list[int] = []
        self.last_status: ExecutionStatus | None = None
        self.last_snapshot: PipelineSnapshot | None = None
        self.last_registers: list[int] = [0] * 32
        self.last_memory: list[int] = [0] * 16

        self.worker_thread = QThread(self)
        self.worker = SerialWorker()
        self.worker.moveToThread(self.worker_thread)
        self.request.connect(self.worker.execute)
        self.worker.result.connect(self.on_result)
        self.worker.error.connect(self.on_error)
        self.worker_thread.start()

        self._build_ui()
        self._apply_style()
        self.refresh_ports()
        self._update_controls()

        self.poll_timer = QTimer(self)
        self.poll_timer.setInterval(500)
        self.poll_timer.timeout.connect(self.poll_status)
        self.poll_timer.start()

    def _build_ui(self) -> None:
        root = QWidget()
        root_layout = QVBoxLayout(root)
        root_layout.addWidget(self._build_connection_panel())
        root_layout.addWidget(self._build_program_panel())
        root_layout.addWidget(self._build_status_panel())

        splitter = QSplitter()
        splitter.addWidget(self._build_pipeline_panel())
        splitter.addWidget(self._build_data_tabs())
        splitter.setSizes([760, 520])
        root_layout.addWidget(splitter, 1)

        log_group = QGroupBox("Mensajes")
        log_layout = QVBoxLayout(log_group)
        self.log_view = QPlainTextEdit()
        self.log_view.setReadOnly(True)
        self.log_view.setMaximumBlockCount(500)
        self.log_view.setMaximumHeight(130)
        log_layout.addWidget(self.log_view)
        root_layout.addWidget(log_group)
        self.setCentralWidget(root)

    def _build_connection_panel(self) -> QGroupBox:
        group = QGroupBox("Conexión")
        layout = QHBoxLayout(group)
        layout.addWidget(QLabel("Puerto:"))
        self.port_combo = QComboBox()
        self.port_combo.setEditable(True)
        self.port_combo.setMinimumWidth(140)
        layout.addWidget(self.port_combo)
        self.refresh_ports_button = QPushButton("Actualizar puertos")
        self.refresh_ports_button.clicked.connect(self.refresh_ports)
        layout.addWidget(self.refresh_ports_button)
        self.connect_button = QPushButton("Conectar")
        self.connect_button.clicked.connect(self.toggle_connection)
        layout.addWidget(self.connect_button)
        self.connection_label = QLabel("● Desconectado")
        self.connection_label.setObjectName("connectionOff")
        layout.addWidget(self.connection_label)
        layout.addStretch()
        layout.addWidget(QLabel("UART 115200 8N1 · CPU 90 MHz"))
        return group

    def _build_program_panel(self) -> QGroupBox:
        group = QGroupBox("Programa y ejecución")
        grid = QGridLayout(group)
        self.file_edit = QLineEdit()
        self.file_edit.setPlaceholderText("Archivo .asm, .s, .hex o .bin")
        self.browse_button = QPushButton("Examinar…")
        self.browse_button.clicked.connect(self.browse_program)
        self.load_button = QPushButton("Cargar programa")
        self.load_button.clicked.connect(self.load_program)
        grid.addWidget(self.file_edit, 0, 0, 1, 5)
        grid.addWidget(self.browse_button, 0, 5)
        grid.addWidget(self.load_button, 0, 6)

        self.run_button = QPushButton("Run")
        self.step_button = QPushButton("Step")
        self.pause_button = QPushButton("Pause")
        self.resume_button = QPushButton("Resume")
        self.reset_button = QPushButton("Reset")
        self.refresh_button = QPushButton("Actualizar estado")
        self.export_button = QPushButton("Exportar snapshot")
        self.run_button.clicked.connect(lambda: self.submit("run", len(self.program_words)))
        self.step_button.clicked.connect(lambda: self.submit("step", None))
        self.pause_button.clicked.connect(lambda: self.submit("pause", None))
        self.resume_button.clicked.connect(lambda: self.submit("resume", None))
        self.reset_button.clicked.connect(lambda: self.submit("reset", None))
        self.refresh_button.clicked.connect(lambda: self.submit("inspect", None))
        self.export_button.clicked.connect(self.export_snapshot)
        for column, button in enumerate(
            (
                self.run_button,
                self.step_button,
                self.pause_button,
                self.resume_button,
                self.reset_button,
                self.refresh_button,
                self.export_button,
            )
        ):
            grid.addWidget(button, 1, column)
        return group

    def _build_status_panel(self) -> QGroupBox:
        group = QGroupBox("Estado global")
        layout = QGridLayout(group)
        self.state_value = QLabel("Desconectado")
        self.cause_value = QLabel("—")
        self.pc_value = QLabel("0x00000000")
        self.cycles_value = QLabel("0")
        self.retired_value = QLabel("0")
        self.valid_value = QLabel("0x0")
        values = (
            ("Estado", self.state_value),
            ("Causa", self.cause_value),
            ("PC fetch", self.pc_value),
            ("Ciclos", self.cycles_value),
            ("Retiradas", self.retired_value),
            ("Valid", self.valid_value),
        )
        for column, (name, value) in enumerate(values):
            layout.addWidget(QLabel(name), 0, column)
            value.setObjectName("metricValue")
            layout.addWidget(value, 1, column)
        return group

    def _build_pipeline_panel(self) -> QGroupBox:
        group = QGroupBox("Pipeline")
        layout = QVBoxLayout(group)
        self.stage_views: dict[str, QPlainTextEdit] = {}
        for stage in ("IF", "IF/ID", "ID/EX", "EX/MEM", "MEM/WB"):
            stage_group = QGroupBox(stage)
            stage_layout = QVBoxLayout(stage_group)
            view = QPlainTextEdit()
            view.setReadOnly(True)
            view.setMaximumHeight(104 if stage != "IF" else 70)
            view.setPlainText("Sin captura")
            stage_layout.addWidget(view)
            layout.addWidget(stage_group)
            self.stage_views[stage] = view
        layout.addStretch()
        return group

    def _build_data_tabs(self) -> QTabWidget:
        tabs = QTabWidget()
        self.register_table = QTableWidget(32, 4)
        self.register_table.setHorizontalHeaderLabels(
            ["Registro", "ABI", "Hexadecimal", "Decimal signed"]
        )
        self.register_table.verticalHeader().setVisible(False)
        for row in range(32):
            self.register_table.setItem(row, 0, QTableWidgetItem(f"x{row}"))
            self.register_table.setItem(row, 1, QTableWidgetItem(ABI[row]))
            self.register_table.setItem(row, 2, QTableWidgetItem("0x00000000"))
            self.register_table.setItem(row, 3, QTableWidgetItem("0"))
        self.register_table.resizeColumnsToContents()
        tabs.addTab(self.register_table, "Registros")

        self.memory_table = QTableWidget(16, 3)
        self.memory_table.setHorizontalHeaderLabels(
            ["Dirección", "Hexadecimal", "Decimal signed"]
        )
        self.memory_table.verticalHeader().setVisible(False)
        for row in range(16):
            self.memory_table.setItem(row, 0, QTableWidgetItem(f"0x{row * 4:08X}"))
            self.memory_table.setItem(row, 1, QTableWidgetItem("0x00000000"))
            self.memory_table.setItem(row, 2, QTableWidgetItem("0"))
        self.memory_table.resizeColumnsToContents()
        tabs.addTab(self.memory_table, "DMEM (primeras 16 palabras)")
        return tabs

    def _apply_style(self) -> None:
        fixed_font = QFont("Consolas", 10)
        for view in self.stage_views.values():
            view.setFont(fixed_font)
        self.log_view.setFont(fixed_font)
        self.setStyleSheet(
            """
            QMainWindow { background: #f4f6f8; }
            QGroupBox { font-weight: 600; border: 1px solid #bcc6d0;
                        border-radius: 6px; margin-top: 8px; padding-top: 8px; }
            QGroupBox::title { subcontrol-origin: margin; left: 10px; padding: 0 4px; }
            QPushButton { min-height: 28px; padding: 2px 10px; }
            QLabel#metricValue { font-family: Consolas; font-size: 14px; font-weight: 700; }
            QLabel#connectionOff { color: #9b1c1c; font-weight: 700; }
            QLabel#connectionOn { color: #16723b; font-weight: 700; }
            """
        )

    def log(self, message: str) -> None:
        self.log_view.appendPlainText(message)

    def refresh_ports(self) -> None:
        current = self.port_combo.currentText()
        ports = available_ports()
        self.port_combo.clear()
        self.port_combo.addItems(ports)
        if current and current not in ports:
            self.port_combo.addItem(current)
        if current:
            self.port_combo.setCurrentText(current)
        elif "COM7" in ports:
            self.port_combo.setCurrentText("COM7")

    def toggle_connection(self) -> None:
        if self.connected:
            self.submit("disconnect", None)
        else:
            port = self.port_combo.currentText().strip()
            if not port:
                QMessageBox.warning(self, "Puerto", "Seleccioná un puerto serie")
                return
            self.submit("connect", port)

    def browse_program(self) -> None:
        path, _ = QFileDialog.getOpenFileName(
            self, "Seleccionar programa", "", "Programas (*.asm *.s *.S *.hex *.bin);;Todos (*)"
        )
        if path:
            self.file_edit.setText(path)

    def load_program(self) -> None:
        try:
            words = load_program_file(self.file_edit.text().strip())
        except Exception as exc:
            self.log(f"ERROR DE PROGRAMA: {exc}")
            QMessageBox.critical(self, "Programa inválido", str(exc))
            return
        if Path(self.file_edit.text().strip()).suffix.lower() in (".asm", ".s"):
            self.log(f"Ensamblado OK: {len(words)} instrucciones/palabras.")
        self.program_words = words
        self.log(f"Cargando {len(words)} palabras…")
        self.submit("load", words)

    def submit(self, operation: str, payload: object) -> None:
        if self.busy:
            return
        self.busy = True
        self._update_controls()
        self.request.emit(operation, payload)

    @Slot(str, object)
    def on_result(self, operation: str, result: object) -> None:
        self.busy = False
        if operation == "connect":
            self.connected = True
            self.poll_timer.start()
            self.connection_label.setText("● Conectado")
            self.connection_label.setObjectName("connectionOn")
            self.connection_label.style().unpolish(self.connection_label)
            self.connection_label.style().polish(self.connection_label)
            self.log(f"Conectado a {self.port_combo.currentText()}.")
            self._set_status(result)
            self.submit("inspect", None)
            return
        if operation == "disconnect":
            self.connected = False
            self.last_status = None
            self.connection_label.setText("● Desconectado")
            self.connection_label.setObjectName("connectionOff")
            self.connection_label.style().unpolish(self.connection_label)
            self.connection_label.style().polish(self.connection_label)
            self.state_value.setText("Desconectado")
            self.log("Conexión cerrada.")
        elif operation == "inspect":
            data = dict(result)
            self._set_status(data["status"])
            if "snapshot" in data:
                self._set_snapshot(data["snapshot"])
                self._set_registers(list(data["registers"]))
                self._set_memory(list(data["memory"]))
        elif isinstance(result, ExecutionStatus):
            previous_active = bool(self.last_status and self.last_status.active)
            self._set_status(result)
            if operation != "status":
                self.log(f"{operation.upper()} completado.")
                self.submit("inspect", None)
                return
            if previous_active and (result.halted or result.paused):
                self.submit("inspect", None)
                return
        self._update_controls()

    @Slot(str, str, bool)
    def on_error(self, operation: str, message: str, connection_lost: bool) -> None:
        # El diálogo modal procesa eventos: detener el polling antes de abrirlo.
        self.poll_timer.stop()
        self.busy = True
        self.log(f"ERROR {operation.upper()}: {message}")
        if connection_lost:
            self.connected = False
            self.last_status = None
            self.last_snapshot = None
            self.connection_label.setText("● Desconectado")
            self.connection_label.setObjectName("connectionOff")
            self.connection_label.style().unpolish(self.connection_label)
            self.connection_label.style().polish(self.connection_label)
            self.state_value.setText("Sin conexión (datos anteriores)")
            message = (
                "No se pudo mantener la comunicación con el puerto serie.\n"
                "Revisá la conexión USB, actualizá los puertos y volvé a conectar.\n\n"
                f"Detalle: {message}"
            )
        self._update_controls()
        QMessageBox.critical(self, f"Error en {operation}", message)
        self.busy = False
        if self.connected:
            self.poll_timer.start()
        self._update_controls()

    def _set_status(self, status: ExecutionStatus) -> None:
        self.last_status = status
        if status.halted:
            state = "Detenido"
        elif status.active:
            state = "Ejecutando"
        elif status.paused:
            state = "Pausado"
        else:
            state = "Inactivo"
        self.state_value.setText(state)
        self.cause_value.setText(CAUSES.get(status.cause, f"Causa {status.cause}"))
        self.pc_value.setText(f"0x{status.pc:08X}")
        self.cycles_value.setText(str(status.cycles))
        self.retired_value.setText(str(status.retired))
        self.valid_value.setText(f"0x{status.valid:X}")
        self._update_controls()

    def _set_snapshot(self, snapshot: PipelineSnapshot) -> None:
        self.last_snapshot = snapshot
        flags = snapshot.flags
        self.stage_views["IF"].setPlainText(
            f"PC fetch: 0x{snapshot.pc:08X}    ciclos: {snapshot.cycles}    "
            f"retiradas: {snapshot.retired}\n"
            f"running={flags & 1} halted={(flags >> 1) & 1} "
            f"enable={(flags >> 2) & 1} fetch_stopped={(flags >> 12) & 1}"
        )
        for name in ("IF/ID", "ID/EX", "EX/MEM", "MEM/WB"):
            stage = snapshot.stage(name)
            text = (
                f"valid={stage['valid']}  PC=0x{stage['pc']:08X}  "
                f"instr=0x{stage['instruction']:08X}\n"
                f"{disassemble(stage['instruction'])}"
            )
            extras = []
            if name == "ID/EX":
                extras.append(
                    f"rs1=x{stage['rs1']}  rs2=x{stage['rs2']}  rd=x{stage['rd']}  "
                    f"A=0x{stage['rs1_data']:08X}  B=0x{stage['rs2_data']:08X}  "
                    f"imm=0x{stage['immediate']:08X}  ctrl=0x{stage['control']:08X}"
                )
            elif name == "EX/MEM":
                extras.append(
                    f"rd=x{stage['rd']}  ALU=0x{stage['alu']:08X}  "
                    f"store=0x{stage['store']:08X}  PC+4=0x{stage['pc4']:08X}  "
                    f"ctrl=0x{stage['control']:08X}"
                )
            elif name == "MEM/WB":
                extras.append(
                    f"rd=x{stage['rd']}  ALU=0x{stage['alu']:08X}  "
                    f"mem=0x{stage['memory']:08X}  WB=0x{stage['writeback']:08X}  "
                    f"ctrl=0x{stage['control']:08X}"
                )
            if extras:
                text += "\n" + "\n".join(extras)
            self.stage_views[name].setPlainText(text)

    @staticmethod
    def _signed32(value: int) -> int:
        return value if value < 0x8000_0000 else value - 0x1_0000_0000

    def _set_registers(self, registers: list[int]) -> None:
        self.last_registers = registers
        for row, value in enumerate(registers):
            self.register_table.item(row, 2).setText(f"0x{value:08X}")
            self.register_table.item(row, 3).setText(str(self._signed32(value)))

    def _set_memory(self, memory: list[int]) -> None:
        self.last_memory = memory
        for row, value in enumerate(memory):
            self.memory_table.item(row, 1).setText(f"0x{value:08X}")
            self.memory_table.item(row, 2).setText(str(self._signed32(value)))

    def _update_controls(self) -> None:
        status = self.last_status
        connected_idle = self.connected and not self.busy
        paused = bool(status and status.paused)
        active = bool(status and status.active)
        self.port_combo.setEnabled(not self.connected and not self.busy)
        self.refresh_ports_button.setEnabled(not self.connected and not self.busy)
        self.connect_button.setEnabled(not self.busy)
        self.connect_button.setText("Desconectar" if self.connected else "Conectar")
        self.browse_button.setEnabled(not self.busy)
        self.load_button.setEnabled(connected_idle)
        self.run_button.setEnabled(connected_idle and bool(self.program_words) and not active)
        self.step_button.setEnabled(connected_idle and paused)
        self.pause_button.setEnabled(connected_idle and active)
        self.resume_button.setEnabled(connected_idle and paused)
        self.reset_button.setEnabled(connected_idle)
        self.refresh_button.setEnabled(connected_idle and not active)
        self.export_button.setEnabled(connected_idle and self.last_snapshot is not None)

    def poll_status(self) -> None:
        if self.connected and not self.busy:
            self.submit("status", None)

    def export_snapshot(self) -> None:
        if self.last_snapshot is None or self.last_status is None:
            return
        path, _ = QFileDialog.getSaveFileName(
            self, "Exportar snapshot", "snapshot.json", "JSON (*.json)"
        )
        if not path:
            return
        payload = {
            "status": self.last_status.__dict__,
            "snapshot_words": [f"0x{word:08X}" for word in self.last_snapshot.words],
            "stages": {
                name: self.last_snapshot.stage(name)
                for name in ("IF/ID", "ID/EX", "EX/MEM", "MEM/WB")
            },
            "registers": [f"0x{value:08X}" for value in self.last_registers],
            "dmem": [
                {"address": index * 4, "value": f"0x{value:08X}"}
                for index, value in enumerate(self.last_memory)
            ],
        }
        Path(path).write_text(
            json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8"
        )
        self.log(f"Snapshot exportado a {path}")

    def closeEvent(self, event: QCloseEvent) -> None:  # noqa: N802 (API Qt)
        self.poll_timer.stop()
        if self.connected:
            self.request.emit("disconnect", None)
        self.worker_thread.quit()
        self.worker_thread.wait(1500)
        event.accept()


def main() -> int:
    app = QApplication(sys.argv)
    app.setApplicationName("TP final RV32I")
    window = MainWindow()
    window.show()
    return app.exec()


if __name__ == "__main__":
    raise SystemExit(main())
