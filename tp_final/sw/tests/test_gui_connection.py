"""Regresión de pérdida de conexión sin hardware ni puerto serie real."""

import os
import sys
import unittest
from pathlib import Path
from unittest.mock import Mock, patch

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "gui"))

from tp_final_gui import QApplication, MainWindow, QMessageBox, SerialWorker


class ConnectionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QApplication.instance() or QApplication([])

    def test_write_failure_releases_client(self):
        worker = SerialWorker()
        client = Mock()
        client.status.side_effect = PermissionError(13, "Acceso denegado")
        worker.client = client
        errors = []
        worker.error.connect(lambda *args: errors.append(args))
        worker.execute("status", None)
        self.assertIsNone(worker.client)
        client.close.assert_called_once()
        self.assertEqual(len(errors), 1)
        self.assertEqual(errors[0][0], "status")
        self.assertTrue(errors[0][2])

    def test_modal_error_cannot_restart_polling(self):
        with patch("tp_final_gui.available_ports", return_value=[]):
            window = MainWindow()
        window.connected = True
        requests = []
        window.request.connect(lambda *args: requests.append(args))

        def modal(*args):
            self.assertFalse(window.poll_timer.isActive())
            self.assertFalse(window.connected)
            self.assertTrue(window.busy)
            window.poll_status()
            self.app.processEvents()
            self.assertEqual(requests, [])

        try:
            with patch.object(QMessageBox, "critical", side_effect=modal):
                window.on_error("status", "WriteFile failed", True)
            self.assertFalse(window.poll_timer.isActive())
            self.assertTrue(window.connect_button.isEnabled())
            self.assertEqual(window.connect_button.text(), "Conectar")
            self.assertEqual(window.connection_label.text(), "● Desconectado")
        finally:
            window.close()


if __name__ == "__main__":
    unittest.main()
