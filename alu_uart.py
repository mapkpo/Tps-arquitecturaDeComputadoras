"""Cliente sencillo para controlar la ALU de la Basys 3 por UART."""

import sys
import time

try:
    import serial
    from serial.tools import list_ports
except ModuleNotFoundError:
    print("Falta instalar pyserial.")
    print("Ejecutá: py -m pip install pyserial")
    sys.exit(1)


BAUD_RATE = 19_200

OPERACIONES = {
    "1": ("ADD", 0x20),
    "2": ("SUB", 0x22),
    "3": ("AND", 0x24),
    "4": ("OR",  0x25),
    "5": ("XOR", 0x26),
    "6": ("SRA", 0x03),
    "7": ("SRL", 0x02),
    "8": ("NOR", 0x27),
}


def elegir_puerto():
    """Muestra los puertos disponibles y devuelve el elegido."""
    puertos = list(list_ports.comports())

    print("\nPuertos serie disponibles:")
    if puertos:
        for numero, puerto in enumerate(puertos, start=1):
            print(f"  {numero}. {puerto.device} - {puerto.description}")

        respuesta = input("Elegí un número o escribí el puerto [1]: ").strip()
        if not respuesta:
            return puertos[0].device

        if respuesta.isdigit():
            indice = int(respuesta) - 1
            if 0 <= indice < len(puertos):
                return puertos[indice].device

        return respuesta.upper()

    print("  No se detectaron puertos automáticamente.")
    return input("Escribí el puerto, por ejemplo COM7: ").strip().upper()


def leer_numero(nombre):
    """Lee un byte en decimal o con prefijo hexadecimal 0x."""
    while True:
        texto = input(f"Valor de {nombre} (0-255 o 0x00-0xFF): ").strip()
        try:
            valor = int(texto, 0)
            if 0 <= valor <= 255:
                return valor
        except ValueError:
            pass

        print("Valor inválido. Ejemplos válidos: 10, 255, 0x0A, 0xFF")


def elegir_operacion():
    """Muestra el menú y devuelve nombre y código de operación."""
    print("\nOperaciones:")
    for opcion, (nombre, codigo) in OPERACIONES.items():
        print(f"  {opcion}. {nombre:<3} (0x{codigo:02X})")
    print("  Q. Salir")

    while True:
        opcion = input("Elegí una operación: ").strip().upper()
        if opcion == "Q":
            return None
        if opcion in OPERACIONES:
            return OPERACIONES[opcion]
        print("Opción inválida.")


def ejecutar_operacion(uart, a, b, codigo):
    """Envía A, B y OP; devuelve el byte recibido o None por timeout."""
    paquete = bytes((a, b, codigo))

    # Descarta respuestas viejas antes de iniciar una operación nueva.
    uart.reset_input_buffer()
    uart.write(paquete)
    uart.flush()

    respuesta = uart.read(1)
    if len(respuesta) != 1:
        return None
    return respuesta[0]


def main():
    print("================================")
    print("       ALU por UART - Basys 3")
    print("================================")

    puerto = elegir_puerto()
    if not puerto:
        print("No se seleccionó ningún puerto.")
        return

    try:
        with serial.Serial(
            port=puerto,
            baudrate=BAUD_RATE,
            bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            timeout=2,
            write_timeout=2,
        ) as uart:
            time.sleep(0.2)
            uart.reset_input_buffer()
            uart.reset_output_buffer()

            print(f"\nConectado a {puerto} a {BAUD_RATE} baud, 8N1.")
            print("La placa debe estar programada y reiniciada con BTNU.")

            while True:
                operacion = elegir_operacion()
                if operacion is None:
                    break

                nombre, codigo = operacion
                a = leer_numero("A")
                b = leer_numero("B")

                resultado = ejecutar_operacion(uart, a, b, codigo)

                print("\n--------------------------------")
                print(f"Operación: {nombre}")
                print(f"Entrada:   A={a} (0x{a:02X}), B={b} (0x{b:02X})")

                if resultado is None:
                    print("ERROR: la FPGA no respondió en 2 segundos.")
                    print("Verificá el bitstream, COM, baud rate y presioná BTNU.")
                else:
                    binario = format(resultado, "08b")
                    con_signo = resultado if resultado < 128 else resultado - 256
                    print(f"Resultado decimal:     {resultado}")
                    print(f"Resultado con signo:   {con_signo}")
                    print(f"Resultado hexadecimal: 0x{resultado:02X}")
                    print(f"Resultado binario:     {binario}")
                print("--------------------------------")

    except serial.SerialException as error:
        print(f"\nNo se pudo abrir o utilizar {puerto}:")
        print(error)
        print("Cerrá PowerShell u otro programa que tenga abierto ese COM.")
    except KeyboardInterrupt:
        print("\nPrograma interrumpido.")

    print("Puerto cerrado.")


if __name__ == "__main__":
    main()
