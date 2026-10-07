# TP final 2026 - Plan de arquitectura y decisiones

Estado: propuesta base para iniciar el diseño. Las decisiones de este documento se consideran aceptadas salvo que una prueba de simulación, síntesis o placa obligue a revisarlas.

## 1. Objetivo del sistema

Construir en una Basys 3 un procesador RISC-V RV32I segmentado en cinco etapas, programable y observable desde una PC mediante UART, sin volver a sintetizar para cambiar el programa.

El sistema completo tendrá tres bloques principales:

1. **Procesador RV32I:** pipeline IF, ID, EX, MEM y WB.
2. **Debug Unit:** controla la ejecución, programa la memoria de instrucciones y permite leer registros, latches del pipeline y memoria de datos.
3. **Software de PC:** ensambla programas, los carga por UART y ofrece una GUI de escritorio para ejecutar y visualizar el estado, más un CLI auxiliar para pruebas automáticas.

## 2. Consignas obligatorias convertidas en criterios de aceptación

### 2.1 Procesador

- Arquitectura de datos de 32 bits e instrucciones de 32 bits, sin extensión comprimida.
- Pipeline de cinco etapas:
  - IF: búsqueda de instrucción.
  - ID: decodificación y lectura del banco de registros.
  - EX: ALU, comparación y cálculo de destinos de salto.
  - MEM: acceso a memoria de datos.
  - WB: escritura del resultado en el banco de registros.
- El reloj físico no se divide ni se bloquea con lógica combinacional. Todos los módulos usan el mismo clock y señales de clock-enable.
- Deben resolverse riesgos estructurales, de datos y de control.
- Al finalizar un programa, el pipeline debe quedar vacío.

### 2.2 Instrucciones obligatorias

| Formato | Instrucciones |
| --- | --- |
| R | `add`, `sub`, `sll`, `srl`, `sra`, `and`, `or`, `xor`, `slt`, `sltu` |
| I - carga | `lb`, `lh`, `lw`, `lbu`, `lhu` |
| I - ALU | `addi`, `andi`, `ori`, `xori`, `slti`, `sltiu`, `slli`, `srli`, `srai` |
| I - salto | `jalr` |
| S | `sb`, `sh`, `sw` |
| B | `beq`, `bne` |
| U | `lui` |
| J | `jal` |

Se implementará la semántica estándar RV32I. En particular, `jal` escribe `PC+4` en `rd` y salta a `PC+inmediato`; `jalr` escribe `PC+4` y usa `(rs1+inmediato) & ~1` como destino.

Además se aceptará la pseudoinstrucción `halt`, ensamblada como `ebreak` (`0x00100073`). No se implementa el resto de las instrucciones SYSTEM.

### 2.3 Debug Unit y UART

La FPGA debe poder enviar a la PC:

- Los 32 registros `x0` a `x31`.
- El contenido completo de los latches IF/ID, ID/EX, EX/MEM y MEM/WB, incluyendo su bit `valid`.
- El contenido solicitado de la memoria de datos.
- Estado de ejecución, PC de fetch, contador de ciclos y causa de parada.

La PC debe poder:

- Programar y reprogramar la memoria de instrucciones por UART.
- Iniciar ejecución continua.
- Avanzar exactamente un ciclo de procesador.
- Pausar, reiniciar y consultar el estado.
- Leer registros, pipeline y memoria sin resintetizar.

### 2.4 Programa y herramienta de carga

- El programa fuente se escribe en ensamblador.
- Una herramienta traduce el ensamblador a palabras máquina de 32 bits.
- La imagen se transmite a la FPGA por UART.
- El programa incluye `halt` de manera explícita.
- El software verifica tamaño, alineación y checksum antes de ejecutar.

### 2.5 Integración y métricas

- Generar reportes de utilización y timing de Vivado.
- Identificar el camino crítico usando timing posterior a implementación, no solamente síntesis.
- Informar WNS/TNS, demora del camino crítico, uso de LUT, FF y BRAM, frecuencia máxima estimada, ciclos ejecutados y CPI de programas de prueba.
- La frecuencia final se decide después de cerrar timing. Si se cambia respecto de los 100 MHz de la placa, se usará Clock Wizard/MMCM; nunca un divisor de reloj implementado con lógica.

## 3. Arquitectura elegida

```text
                     +---------------- PC ----------------+
                     v                                    |
  IMEM --> IF/ID --> ID/EX --> EX/MEM --> MEM/WB --> banco de registros
                         |          |
                    forwarding     DMEM
                         |
                   hazard/control

  PC <--> UART <--> Debug Unit <--> control de ejecución / IMEM / snapshot
```

### 3.1 Decisiones del pipeline

- **Pipeline:** cinco etapas clásicas, single-issue e in-order.
- **Memorias Harvard:** memoria de instrucciones y memoria de datos separadas. Esto elimina el riesgo estructural entre IF y MEM.
- **Banco de registros:** 32 registros de 32 bits, dos lecturas combinacionales y una escritura sincrónica. `x0` siempre vale cero.
- **Validación:** cada latch de pipeline lleva un bit `valid`. Las instrucciones anuladas no pueden escribir registros ni memoria.
- **Forwarding:** desde EX/MEM y MEM/WB hacia las entradas de EX. También se reenvía el dato de un `store`.
- **Load-use:** una dependencia inmediata de un `load` genera un stall de un ciclo e inserta una burbuja.
- **Lectura y escritura del mismo registro:** se agrega bypass de WB hacia ID para evitar depender del comportamiento específico de la memoria inferida.
- **Saltos:** `beq`, `bne`, `jal` y `jalr` se resuelven en EX. Si cambian el flujo, se invalidan IF/ID e ID/EX.
- **HALT:** cuando `halt` llega a ID se deja de buscar y decodificar. Las instrucciones más antiguas siguen avanzando hasta vaciar el pipeline. Recién entonces el estado pasa a `HALTED`.
- **Errores:** instrucción ilegal, acceso desalineado o dirección fuera de rango detienen el ingreso de instrucciones, vacían el pipeline y dejan una causa de parada legible por la Debug Unit.

No existen riesgos WAR ni WAW porque el procesador es in-order, emite una instrucción por ciclo y escribe solamente en WB.

### 3.2 Memorias

- **IMEM:** 4 KiB, 1024 palabras de 32 bits, direccionada por palabra.
- **DMEM:** 4 KiB, direccionada por byte y con enables por byte para `sb`, `sh` y `sw`.
- **Endianness:** little-endian.
- **Alineación:** `lw/sw` requieren múltiplo de 4 y `lh/lhu/sh` múltiplo de 2. Un acceso desalineado genera una parada por error; no se implementan accesos que crucen palabras.
- **Implementación:** memorias sin reset masivo en RTL para favorecer inferencia de BRAM. El borrado, cuando se solicita, lo realiza una FSM escribiendo una dirección por ciclo.
- **Límite de programa:** la Debug Unit conserva `program_words`. Un fetch fuera de la imagen cargada se trata como fin anormal de programa y vacía el pipeline.

Los tamaños son parámetros y pueden modificarse si la utilización de BRAM o los programas de prueba lo requieren.

## 4. Modos de ejecución

### 4.1 Continuo

1. La PC envía `RUN` con un límite máximo de ciclos.
2. El procesador mantiene `cpu_ce=1` y ejecuta a la frecuencia del sistema.
3. Ante `halt`, error, pausa o watchdog, se detiene el fetch y se vacía el pipeline.
4. La FPGA envía un evento con la causa de parada.
5. La GUI solicita y muestra un snapshot completo.

### 4.2 Paso a paso

1. La PC envía `STEP`.
2. La Debug Unit genera un solo pulso de `cpu_ce`.
3. Todo el pipeline avanza exactamente un ciclo; el reloj físico nunca se detiene.
4. La GUI solicita un snapshot atómico y muestra el nuevo estado.
5. Si se encontró `halt`, los siguientes pasos drenan las instrucciones antiguas. `HALTED` sólo se informa cuando todos los bits `valid` valen cero.

### 4.3 Programa sin HALT

- Si la ejecución secuencial supera `program_words`, se detiene por `PC_OUT_OF_RANGE`.
- Si el programa queda en un loop, continúa hasta recibir `PAUSE` o alcanzar el watchdog indicado en `RUN`.
- La GUI usará un watchdog por defecto; por eso una falla de software no deja la sesión bloqueada indefinidamente.

## 5. Reprogramación y estado inicial

Secuencia elegida:

1. `LOAD_BEGIN` pausa el procesador y vacía el pipeline.
2. Se carga la nueva imagen en IMEM por bloques.
3. `LOAD_END` valida cantidad de palabras y CRC32.
4. Antes de ejecutar se coloca `PC=0` y se limpian `x1` a `x31`.
5. DMEM se limpia por defecto para que la ejecución sea repetible, con una opción explícita para conservarla.
6. La IMEM completa no necesita borrarse: sólo se consideran ejecutables las `program_words` de la imagen nueva. Habrá un comando opcional de borrado total.

Respuestas a las preguntas de la consigna:

- **¿Es necesario vaciar la memoria de datos?** No para que el hardware funcione, pero sí es el valor por defecto para obtener pruebas deterministas. Puede conservarse bajo pedido.
- **¿Y los registros?** Se limpian al iniciar una imagen nueva, excepto `x0`, que siempre es cero. Reiniciar la misma imagen podrá ofrecer una opción de conservación para experimentación.
- **¿Se necesita vaciar el pipeline?** Sí, siempre antes de reprogramar y antes de declarar terminada una ejecución.
- **¿Y la memoria de programa?** No completa; el límite `program_words` vuelve inaccesible el contenido viejo. Se sobrescribe la nueva imagen y se valida con CRC32.

## 6. Protocolo de depuración

Se conserva la UART 8N1 del TP2 y se agrega arriba un protocolo binario con framing y detección de errores.

### 6.1 Formato de paquete

```text
MAGIC[2] | VERSION[1] | SEQ[1] | CMD[1] | LENGTH[2] | PAYLOAD[LENGTH] | CRC16[2]
  A5 5A       01
```

- Todos los enteros multibyte se transmiten little-endian.
- `LENGTH` evita que bytes `A5 5A` dentro del payload se interpreten como un paquete nuevo.
- CRC16-CCITT protege cada paquete.
- Las respuestas usan el mismo `SEQ`, el comando con bit 7 en uno y un byte inicial de estado.
- Los bloques de programa agregan CRC32 de la imagen completa en `LOAD_END`.

### 6.2 Comandos mínimos

| Código | Comando | Función |
| --- | --- | --- |
| `0x01` | `PING` | Versión y capacidades |
| `0x02` | `GET_STATUS` | Estado, causa, PC, ciclos y programa cargado |
| `0x10` | `LOAD_BEGIN` | Inicia una reprogramación y define tamaño/opciones |
| `0x11` | `LOAD_WORDS` | Escribe un bloque de palabras en IMEM |
| `0x12` | `LOAD_END` | Verifica tamaño y CRC32 |
| `0x20` | `RUN` | Ejecuta en continuo con watchdog |
| `0x21` | `STEP` | Avanza un ciclo de procesador |
| `0x22` | `PAUSE` | Congela el estado actual |
| `0x23` | `RESET_CORE` | Reinicia PC, pipeline y estado seleccionado |
| `0x30` | `READ_REGS` | Devuelve los 32 registros |
| `0x31` | `READ_PIPELINE` | Devuelve todos los latches y bits `valid` |
| `0x32` | `READ_DMEM` | Lee un rango de memoria de datos |
| `0x33` | `SNAPSHOT` | Registros, pipeline y estado en una captura consistente |

`RUN` responde inmediatamente. Cuando termina, la FPGA emite un evento `HALTED`, `FAULT`, `PAUSED` o `WATCHDOG`; así la ausencia de `halt` no bloquea el protocolo.

### 6.3 Snapshot de pipeline

Como mínimo se transmiten:

- IF: PC de fetch y estado del controlador.
- IF/ID: `valid`, PC e instrucción.
- ID/EX: `valid`, PC, instrucción, operandos, inmediato, `rs1`, `rs2`, `rd` y control.
- EX/MEM: `valid`, PC, instrucción, resultado ALU, dato de store, `rd` y control.
- MEM/WB: `valid`, PC, instrucción, dato leído, resultado ALU, `rd` y control.

El snapshot sólo se toma con el core pausado o detenido, para que todos los datos pertenezcan al mismo ciclo.

## 7. Software de PC

### 7.1 Ensamblador

Se implementará un ensamblador Python de dos pasadas para el subconjunto requerido:

- Etiquetas y referencias hacia adelante/atrás.
- Literales decimales, hexadecimales y negativos.
- Directiva `.word`.
- Pseudoinstrucciones `nop` y `halt`.
- Verificación de rango y alineación de inmediatos.
- Salidas `.bin`, `.hex` y `.map`.

Esto evita depender de que el laboratorio tenga instalado un toolchain RISC-V. La carga de archivos generados por GNU assembler podrá agregarse como compatibilidad, pero no será un requisito del flujo principal.

### 7.2 Interfaz gráfica

La interfaz principal será una GUI de escritorio en Python con **PySide6/Qt**. El CLI no interactivo se conserva para tests, automatización y diagnóstico, pero compartirá el mismo cliente de protocolo que la GUI.

La comunicación serie se ejecutará fuera del hilo de la interfaz mediante un worker y señales Qt. De esta forma una carga, un timeout o un dump de memoria no congelan la ventana.

Paneles propuestos:

- Conexión, estado, causa de parada y contadores.
- Registros en ABI y formato hexadecimal/decimal.
- Cinco etapas del pipeline con PC, instrucción y desensamblado.
- Memoria de datos en hexadecimal.
- Barra de conexión: puerto COM, baud rate, conectar/desconectar y estado de enlace.
- Controles mediante botones: **Cargar programa**, **Run**, **Step**, **Pause**, **Reset** y **Exportar snapshot**.
- Selector del archivo assembler y panel de mensajes de compilación/carga.

Los botones se habilitarán según el estado real del sistema. Por ejemplo, `Step` sólo estará disponible con el procesador pausado, mientras que `Pause` sólo estará disponible durante una ejecución continua.

Se reutilizan la detección de puertos, la configuración `pyserial` y el manejo de errores del cliente del TP2.

## 8. Reutilización del TP2

### 8.1 Reutilización directa, luego de regresión

- `baud_rate_generator.v`.
- `uart_rx.v`, `uart_rx_control.v`, `uart_rx_datapath.v`.
- `uart_tx.v`, `uart_tx_control.v`, `uart_tx_datapath.v`.
- `uart.v`, incluidos sus buffers y flags de overrun/frame error.
- Pines de clock, reset y UART del XDC de Basys 3.
- Testbench UART y sus tareas como BFM para las pruebas de integración.
- Scripts Tcl de síntesis y generación de reportes.

La UART es parametrizable. Se comenzará con **115200 baud, 8N1 y oversampling 16x**; a 100 MHz el error de baud es suficientemente pequeño para probar en placa. Si las pruebas físicas no son estables, el protocolo permite volver a 19200 sin rediseñar el core.

El buffer actual de un byte es suficiente inicialmente porque hay miles de ciclos de sistema entre bytes UART. Sólo se agregará una FIFO si las pruebas de tráfico continuo muestran overrun.

### 8.2 Reutilización conceptual o parcial

- `alu.v`: sirve como referencia de estilo, pero se reemplaza por una ALU RV32 de 32 bits y códigos de control internos nuevos.
- `alu_uart_controller.v`: se reemplaza por el parser de paquetes y la FSM de Debug Unit.
- `top_alu_uart.v`: se usa como referencia de integración, pero el top nuevo conectará procesador, memorias y Debug Unit.
- `alu_uart.py`: se conservan selección de COM, apertura/cierre, timeouts y mensajes; se reemplazan menú y paquete A/B/OP.
- `reg_nbits.v`: puede usarse para registros simples, pero los latches del pipeline tendrán módulos explícitos con `enable`, `flush` y `valid`.

### 8.3 Componentes que no se arrastran al diseño final

- `alu_registered.v` y el protocolo fijo de tres bytes A/B/OP.
- Códigos de operación tipo MIPS usados por la ALU de 8 bits.
- LEDs dedicados a `zero`, `carry` y `overflow` como interfaz principal. Algunos LEDs pueden conservarse para estado global (`RUNNING`, `HALTED`, `ERROR`, RX/TX).

## 9. Estructura prevista del proyecto

```text
tp_final/
  docs/                 arquitectura, protocolo y decisiones
  rtl/
    common/             UART reutilizada y utilidades
    core/               pipeline, ALU, decoder, hazards y registros
    memory/             IMEM y DMEM
    debug/              protocolo, ejecución y snapshot
    top/                integración Basys 3
  sim/
    unit/               pruebas de cada módulo
    integration/        procesador + debug + UART
    programs/           programas assembler de validación
  sw/
    assembler/          ensamblador y desensamblador
    client/             protocolo serie
    gui/                interfaz gráfica PySide6/Qt
  constraints/          XDC
  scripts/              simulación, síntesis e implementación
  reports/              timing, utilización y resultados
```

## 10. Estrategia de verificación

### 10.1 Pruebas unitarias

- Decoder y generador de inmediatos por cada formato.
- ALU para operaciones signed/unsigned y shifts de 0 a 31.
- Banco de registros y comportamiento de `x0`.
- Loads/stores por tamaño, extensión de signo y byte lanes.
- Unidad de forwarding y detector de load-use.
- Flush de saltos y HALT.
- Parser UART: paquetes válidos, CRC incorrecto, longitud inválida y recuperación de sincronismo.
- Ensamblador: encoding conocido y errores de rango/alineación.

### 10.2 Pruebas de integración

- Una instrucción aislada de cada tipo.
- Cadenas de dependencias EX/EX, MEM/EX y load-use.
- Branch tomado y no tomado, con instrucciones que deben anularse.
- `jal` y `jalr`, comprobando el link register.
- Programa completo de aritmética y memoria.
- Carga, ejecución, reprogramación y segunda ejecución sin resíntesis.
- Modo step: un comando equivale a un ciclo.
- Ausencia de HALT: fin de imagen, watchdog y pausa manual.
- Snapshot: comparación de registros/memoria con un modelo de referencia Python.

### 10.3 Propiedades invariantes

- `x0 == 0` en todo momento.
- Un latch con `valid=0` no produce efectos laterales.
- Una instrucción anulada nunca escribe registro ni memoria.
- Cada store válido escribe una sola vez.
- `HALTED` implica que todos los latches tienen `valid=0`.
- Nunca se ejecuta una dirección fuera de `program_words`.

## 11. Etapas de trabajo y definición de terminado

### Etapa A - Base y especificación

- Congelar este documento.
- Copiar la UART reutilizable al nuevo árbol sin modificar el TP2.
- Ejecutar nuevamente sus testbenches.
- Definir estructuras de latches y encodings de control.

### Etapa B - Procesador mínimo

- Decoder, inmediatos, ALU, banco de registros y memorias.
- Pipeline sin hazards con programas que incluyan NOPs.
- Pruebas por instrucción.

### Etapa C - Hazards y control

- Forwarding, stalls, flushes, HALT y errores.
- Comparación contra modelo de referencia sin NOPs manuales.

### Etapa D - Debug Unit

- Protocolo de paquetes, programación de IMEM, run/step/pause y snapshot.
- Testbench extremo a extremo usando UART serial real, no accesos jerárquicos.

### Etapa E - Software

- Ensamblador, cliente, CLI y GUI.
- Carga y reprogramación verificadas con CRC.

### Etapa F - Placa y cierre

- Bitstream, pruebas físicas, timing posterior a implementación y utilización.
- Determinar/aplicar frecuencia final.
- Capturas de la GUI, diagramas, métricas y memoria técnica.

El TP se considera terminado cuando todos los tests pasan, la placa puede cargar dos programas diferentes consecutivamente sin resíntesis, ambos modos funcionan, el pipeline termina vacío y los reportes de timing no tienen violaciones.

## 12. Decisiones que quedan deliberadamente para medición

Sólo quedan abiertas decisiones que dependen de evidencia:

- Frecuencia final del clock después del timing post-route.
- Necesidad de FIFO UART después de la prueba de tráfico continuo.
- Tamaño final de IMEM/DMEM si los programas o la utilización justifican cambiar 4 KiB.

El resto de las decisiones tiene una opción base definida para evitar bloquear la implementación.
