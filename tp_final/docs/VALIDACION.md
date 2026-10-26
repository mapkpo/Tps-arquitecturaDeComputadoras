# Registro de validaciones

## Infraestructura UART

- Placa: Basys 3.
- Clock: 100 MHz.
- UART: 115200 baud, 8N1.
- Resultado: eco UART verificado físicamente.

## ALU RV32

- Fecha de confirmación: 2026-10-12.
- Simulación unitaria: aprobada.
- Simulación de integración UART-ALU: aprobada.
- Implementación: DRC sin observaciones y timing cumplido a 100 MHz.
- Prueba física: aprobada en Basys 3 por COM7.
- Operaciones verificadas: `ADD`, `SUB`, `SLL`, `SRL`, `SRA`, `AND`, `OR`, `XOR`, `SLT`, `SLTU` y `COPY_B`.
- Casos especiales verificados: overflow modular, resultado negativo, shift de 31 bits y comparaciones signed/unsigned.

## Banco de registros RV32

- Fecha de confirmación: 2026-10-12.
- Simulación unitaria: aprobada.
- Simulación de integración UART-banco: aprobada.
- Implementación: DRC sin observaciones.
- Timing lectura/escritura entre flancos: cumplido, slack `+0.847 ns` sobre una ventana de `5.000 ns` a 100 MHz.
- Utilización del top de prueba: 729 LUT y 1290 registros.
- Prueba física: aprobada en Basys 3 por COM7.
- Casos verificados: lectura simultánea por ambos puertos, `x1`, `x2`, `x31`, sobrescritura y escritura ignorada sobre `x0`.
- Estado: etapa completada.

## Decoder y generador de inmediatos RV32I

- Fecha de implementación y confirmación física: 2026-10-12.
- Simulación unitaria: aprobada para todas las instrucciones requeridas, `ebreak` y encodings ilegales.
- Simulación de integración UART-decoder: aprobada.
- Formatos de inmediato verificados: I, S, B, U y J, incluyendo extensión de signo y alineación implícita de B/J.
- Seguridad ante instrucción ilegal: todos los controles con efectos laterales quedan desactivados.
- Implementación: DRC con 0 observaciones y timing cumplido a 100 MHz.
- Timing post-route: WNS `+5.336 ns`, TNS `0.000 ns`, WHS `+0.104 ns` y THS `0.000 ns`.
- Utilización del top de prueba: 208 LUT y 227 registros; 0 BRAM.
- Prueba física: aprobada en Basys 3 por COM7.
- Casos físicos verificados: las 32 instrucciones requeridas, `ebreak/halt` y tres encodings ilegales.
- Estado: etapa completada.

## Memorias Harvard RV32

- Fecha de implementación y confirmación física: 2026-10-12.
- Organización: IMEM de 4 KiB (1024 x 32 bits) y DMEM de 4 KiB, separadas y sin caché.
- Convención de flancos: escrituras en flanco positivo y lecturas registradas en flanco negativo.
- Simulación unitaria: aprobada para IMEM y DMEM.
- Simulación de integración UART-memorias: aprobada.
- Casos simulados: accesos byte/half/word, little-endian, extensión signed/unsigned, extremos de ambas memorias, direcciones desalineadas y fuera de rango.
- Inferencia: Vivado reconoció dos memorias `1 K x 32` y las implementó en 2 `RAMB36E1` (una BRAM36 por memoria).
- Implementación: DRC con 0 observaciones y timing cumplido a 100 MHz.
- Timing post-route: WNS `+0.088 ns`, TNS `0.000 ns`, WHS `+0.034 ns` y THS `0.000 ns`.
- Utilización del top de prueba: 257 LUT, 375 registros y 2 BRAM36.
- Prueba física: aprobada en Basys 3 por COM7.
- Casos físicos verificados: lectura y escritura de IMEM; `sb`, `sh`, `sw`, `lb`, `lbu`, `lh`, `lhu` y `lw`; little-endian; extensión de signo; conservación de palabras; dirección final; accesos desalineados y fuera de rango.
- Estado combinado verificado: `0x03` cuando un acceso half-word en el límite es simultáneamente desalineado y fuera de rango.
- Estado: etapa completada.

## Pipeline RV32I básico de cinco etapas

- Fecha de implementación y confirmación física: 2026-10-12.
- Etapas conectadas: IF, ID, EX, MEM y WB con latches y bits `valid`.
- Componentes reutilizados: IMEM, decoder/inmediatos, banco de registros, ALU y DMEM ya validados.
- Convención de flancos: estado y escrituras en flanco positivo; lecturas de IMEM, banco y DMEM en flanco negativo.
- Riesgos de control: branch tomado resuelto en EX con limpieza de IF/ID e ID/EX.
- Riesgos de datos: todavía sin forwarding ni stalls; el programa de esta etapa inserta tres `nop` entre productor y consumidor.
- HALT: `ebreak` detiene el fetch y sólo declara el core detenido cuando los cuatro latches están vacíos.
- Errores implementados: instrucción ilegal, PC fuera de la imagen, acceso de datos desalineado y fuera de rango.
- Simulación del core: aprobada; 38 ciclos, 31 instrucciones retiradas, causa `HALT` y pipeline vacío.
- Simulación extremo a extremo UART-pipeline: aprobada.
- Programa verificado: `addi`, `add`, `sw`, `lw`, `lui`, `beq`, `ebreak` y `nop`; también se comprobó el descarte de dos instrucciones del camino incorrecto.
- Estado arquitectónico verificado: `x0` a `x8` y `DMEM[0]`.
- Inferencia: IMEM y DMEM continúan implementadas en 2 `RAMB36E1`.
- Implementación: DRC con 0 observaciones y timing cumplido a 100 MHz.
- Timing post-route: WNS `+0.178 ns`, TNS `0.000 ns`, WHS `+0.058 ns` y THS `0.000 ns`.
- Utilización del top de prueba: 2064 LUT, 2064 registros y 2 BRAM36.
- Prueba física: aprobada en Basys 3 por COM7.
- Resultado físico: PC final `0x00000088`, 38 ciclos, 31 instrucciones retiradas, causa `HALT=1` y latches `valid=0`.
- Estado físico verificado: `x0=0`, `x1=5`, `x2=7`, `x3=12`, `x4=12`, `x5=10`, `x6=0x12345000`, `x7=10`, `x8=42` y `DMEM[0]=12`.
- Estado: etapa completada.

## Forwarding y stalls del pipeline RV32I

- Fecha de implementación: 2026-10-12.
- Forwarding implementado desde EX/MEM y MEM/WB hacia EX, con prioridad para EX/MEM.
- Caminos cubiertos: operandos de ALU, comparaciones de branch, destino de `jalr` y dato de `store`.
- Los loads no reenvían desde EX/MEM: una dependencia `load-use` detiene PC e IF/ID durante un ciclo e inserta una burbuja en ID/EX.
- Bypass WB-ID implementado para resolver la lectura y escritura simultánea del mismo registro sin depender del comportamiento de la memoria inferida.
- Programa de prueba: 18 instrucciones consecutivas sin `nop`, con dependencias EX/EX y MEM/EX, tres casos `load-use`, branch tomado, dos instrucciones anuladas, stores dependientes y `ebreak`.
- Simulación directa: aprobada con exactamente 3 stalls, 25 ciclos, 15 instrucciones retiradas, PC final `0x00000048`, causa `HALT` y pipeline vacío.
- Simulación extremo a extremo UART-pipeline: aprobada.
- Estado arquitectónico verificado: `x0` a `x11`, `DMEM[0]=17`, `DMEM[4]=42` y `DMEM[8]=42`.
- Inferencia: IMEM y DMEM continúan implementadas en 2 `RAMB36E1`.
- Implementación: DRC con 0 observaciones y timing cumplido a 100 MHz.
- Timing post-route: WNS `+0.064 ns`, TNS `0.000 ns`, WHS `+0.063 ns` y THS `0.000 ns`.
- Utilización del top de prueba: 2128 LUT, 2060 registros y 2 BRAM36.
- Prueba física: aprobada en Basys 3 por COM7.
- Resultado físico: PC final `0x00000048`, 25 ciclos, 15 instrucciones retiradas, causa `HALT=1` y latches `valid=0`.
- Registros físicos: `x0=0`, `x1=5`, `x2=12`, `x3=17`, `x4=17`, `x5=15`, `x6=32`, `x7=32`, `x8=42`, `x9=42`, `x10=42` y `x11=43`.
- Memoria física: `DMEM[0]=17`, `DMEM[4]=42` y `DMEM[8]=42`.
- Estado: etapa completada.

## Cobertura completa del subconjunto RV32I obligatorio

- Fecha de implementación: 2026-10-12.
- Programa fuente documentado en `sim/programs/rv32i_coverage.S`: 52 palabras consecutivas sin `nop`.
- Instrucciones R verificadas: `add`, `sub`, `sll`, `srl`, `sra`, `and`, `or`, `xor`, `slt` y `sltu`.
- Instrucciones inmediatas verificadas: `addi`, `andi`, `ori`, `xori`, `slti`, `sltiu`, `slli`, `srli` y `srai`.
- Memoria verificada: `lb`, `lh`, `lw`, `lbu`, `lhu`, `sb`, `sh` y `sw`, incluyendo extensión de signo y cero y composición little-endian de byte lanes.
- Control verificado: `beq` y `bne` tomados y no tomados, `jal`, `jalr`, links `PC+4`, cuatro redirecciones y descarte de ocho instrucciones del camino incorrecto.
- También verificados: `lui` y `ebreak` como `halt`.
- Simulación directa: aprobada; los 32 registros y `DMEM[0]=0x00AA8000` coinciden con el modelo.
- Simulación extremo a extremo UART-pipeline: aprobada con la misma imagen.
- Resultado simulado: PC final `0x000000D0`, 56 ciclos, 43 instrucciones retiradas, causa `HALT=1` y pipeline vacío.
- Inferencia: IMEM y DMEM continúan implementadas en 2 `RAMB36E1`.
- Implementación: DRC con 0 observaciones y timing cumplido a 100 MHz.
- Timing post-route: WNS `+0.064 ns`, TNS `0.000 ns`, WHS `+0.063 ns` y THS `0.000 ns`.
- Utilización: 2128 LUT, 2060 registros y 2 BRAM36.
- Cliente: `sw/client/rv32i_coverage_test.py`.
- Prueba física: aprobada en Basys 3 por COM7.
- Resultado físico: PC final `0x000000D0`, 56 ciclos, 43 instrucciones retiradas, causa `HALT=1` y pipeline vacío.
- Registros físicos: los 32 registros coincidieron con el modelo, incluidos los links `x29=0x000000AC` de `jal` y `x31=0x000000C0` de `jalr`.
- Memoria física: `DMEM[0]=0x00AA8000`, confirmando la combinación little-endian de `sw`, `sb` y `sh`.
- Estado: etapa completada.

## Control de ejecución de la Debug Unit

- Fecha de implementación: 2026-10-12.
- Comandos incrementales: `START_PAUSED` (`0x24`), `STEP` (`0x25`), `PAUSE` (`0x26`), `RESUME` (`0x27`) y `RESET_CORE` (`0x28`).
- `STEP` genera un único ciclo habilitado sin dividir ni bloquear físicamente el clock.
- El estado distingue ejecución activa, pausa, `HALT`, causa, bits `valid`, PC, ciclos e instrucciones retiradas.
- Los registros y DMEM pueden consultarse con el pipeline pausado; la programación de IMEM continúa bloqueada mientras el core conserva una ejecución activa o pausada.
- Regresión UART: aprobada para arranque pausado, ocho pasos exactos hasta `HALT`, rechazo de `STEP` detenido, pausa estable de un loop, paso desde pausa, reanudación y reset.
- Optimización de timing: el chequeo de rango de DMEM se reescribió como decodificación estructural para eliminar el comparador genérico de 32 bits del camino hacia BRAM; la regresión unitaria de memorias volvió a aprobarse.
- Implementación: DRC con 0 observaciones y timing cumplido a 100 MHz.
- Timing post-route: WNS `+0.047 ns`, TNS `0.000 ns`, WHS `+0.036 ns` y THS `0.000 ns`.
- Decisión de frecuencia: 100 MHz continúa siendo válido para esta etapa, pero no es un requisito del profesor; 80 MHz queda definido como alternativa si los siguientes incrementos no conservan margen suficiente.
- Utilización: 2176 LUT, 2066 registros y 2 BRAM36.
- Cliente: `sw/client/execution_control_test.py`.
- Prueba física: aprobada en Basys 3 por COM7.
- Resultado físico por pasos: el programa de cuatro palabras alcanzó `HALT` exactamente después de 8 pasos, con 3 instrucciones retiradas, pipeline vacío, `x1=1`, `x2=3` y `DMEM[0]=3`.
- Resultado físico de pausa: el estado permaneció estable durante la pausa; un `STEP` aumentó ciclos y retiradas exactamente en uno, y `RESUME` reanudó el loop antes de una nueva pausa.
- Resultado físico de reset: `RESET_CORE` dejó PC, contadores, registros, bits `valid`, pausa y `HALT` en cero.
- Estado: etapa completada.

## Snapshot completo del pipeline

- Fecha de implementación: 2026-10-12.
- Comando incremental: `SNAPSHOT` (`0x29`), sin payload.
- Respuesta aprobada: un byte de estado seguido de 32 palabras little-endian; incluye cabecera/versionado, estado global, PC, ciclos, retiradas y todos los campos de IF/ID, ID/EX, EX/MEM y MEM/WB.
- Atomicidad: el comando sólo se acepta con el core pausado, detenido o inactivo; una solicitud durante ejecución activa devuelve `0x80` y no transmite payload.
- Regresión UART: aprobada con cuatro instrucciones distintas ocupando simultáneamente las cuatro etapas. Se comprobaron PC, instrucción, operandos, inmediato, registros fuente/destino, señales de control, ALU, store, memoria, `PC+4` y write-back.
- Compatibilidad: la regresión completa de cobertura RV32I y la de `Run`, `Step`, `Pause`, `Resume` y `Reset` continúan aprobadas.
- Medición inicial: a 100 MHz apareció una violación de un solo camino de medio ciclo hacia DMEM, con WNS `-0.184 ns`.
- Decisión de frecuencia: se adoptaron 80 MHz reales mediante MMCM desde el oscilador de 100 MHz de la Basys 3.
- Implementación final: DRC con 0 observaciones y todas las restricciones de timing cumplidas.
- Timing post-route a 80 MHz: WNS `+0.402 ns`, TNS `0.000 ns`, WHS `+0.037 ns` y THS `0.000 ns`.
- Utilización: 2486 LUT, 2207 registros y 2 BRAM36.
- Bitstream usado en esta etapa: reemplazado por el bitstream final consolidado de 90 MHz.
- SHA-256: `56759BEEB9CCF0CC468589C9F71A6201EEC713B09E5F3562B3A389260D4CB02E`.
- Cliente: `sw/client/pipeline_snapshot_test.py`.
- Prueba física: aprobada en Basys 3 por COM7 a 80 MHz internos.
- Resultado físico global: cabecera `SNAP`, versión 1, 32 palabras, PC `0x00000010`, 4 ciclos, 0 retiradas y `valid=0xF`.
- Resultado físico IF/ID: PC `0x0000000C`, instrucción `0x00100073` (`ebreak`).
- Resultado físico ID/EX: PC `0x00000008`, instrucción `0x00202023` (`sw`), registros `0x00000200` y control `0x00000282`.
- Resultado físico EX/MEM: PC `0x00000004`, instrucción `0x00208113`, ALU `0x00000003`, `PC+4=0x00000008` y control `0x00000211`.
- Resultado físico MEM/WB: PC `0x00000000`, instrucción `0x00100093`, ALU/write-back `0x00000001`, `PC+4=0x00000004` y control `0x00000009`.
- Estado: etapa completada.

## Cliente reutilizable y GUI PySide6

- Fecha de implementación: 2026-10-12.
- Cliente común: `sw/client/tp_final_client.py`.
- Funciones: detección de puertos, conexión, programación de IMEM, `Run`, `Step`, `Pause`, `Resume`, `Reset`, estado, registros, DMEM y snapshot tipado.
- Parser: valida magic `SNAP`, versión y cantidad de palabras antes de exponer los campos de cada latch.
- Desensamblador: `sw/client/rv32i_disassembler.py`, limitado al subconjunto RV32I implementado.
- GUI: `sw/gui/tp_final_gui.py`, con worker UART en `QThread`, carga `.hex/.bin`, controles condicionados por estado, pipeline, registros, DMEM, mensajes y exportación JSON.
- Programa de demostración: `sw/programs/pipeline_demo.hex`.
- Pruebas automáticas: 5 casos aprobados para parser, rechazo de formatos inválidos, carga `.hex/.bin` y desensamblado.
- Prueba de arranque Qt: aprobada en modo offscreen con PySide6 6.12.0.
- Prueba física del cliente común: aprobada por COM7; luego de cuatro pasos informó magic `SNAP`, PC `0x00000010`, 4 ciclos y `valid=0xF`.
- Validación visual/interactiva de la GUI: pendiente.

## Ensayo de frecuencia a 90 MHz

- Fecha del ensayo: 2026-10-12.
- Configuración: MMCM con VCO a 900 MHz y divisor de salida 10, generando 90 MHz desde el oscilador de 100 MHz.
- Implementación: completada sin errores ni advertencias críticas; DRC con 0 observaciones.
- Timing post-route: WNS `+0.376 ns`, TNS `0.000 ns`, WHS `+0.039 ns` y THS `0.000 ns`.
- Resultado: todas las restricciones de timing se cumplen a 90 MHz.
- Utilización: 2477 LUT, 2207 registros y 2 BRAM36.
- Bitstream final: `output/bitstream/top_tp_final_90mhz.bit`.
- SHA-256: `CA4C960EB65C899594419D61467BA27AC2D94B97AAFE720E8FFA170EA1461D83`.
- Prueba física: aprobada en Basys 3 por COM7 con `pipeline_snapshot_test.py`.
- Resultado físico: cabecera `SNAP`, PC `0x00000010`, 4 ciclos, `valid=0xF` y contenido correcto en IF/ID, ID/EX, EX/MEM y MEM/WB.
- Estado: aprobado por implementación y validación física; 90 MHz adoptado como frecuencia final.

## Consolidación del proyecto

- Frecuencia y configuración por defecto: 90 MHz mediante MMCM.
- Bitstream para USB-UART integrado: `output/bitstream/top_tp_final_90mhz.bit`.
- Reportes base conservados: `reports/final/timing_90mhz.rpt`, `utilization_90mhz.rpt` y `drc_90mhz.rpt`.
- Se eliminaron bitstreams/reportes de etapas incrementales, logs de Vivado, cachés Python y el proyecto Vivado antiguo `vivado/tp_final`.
- Se conserva `vivado/pipeline_test/tp_final.xpr` como único proyecto de trabajo.
- Se conservan RTL, testbenches y scripts de simulación incremental porque forman la regresión del procesador.

## Variante UART externa CP2102

- Fecha de implementación: 2026-10-13.
- Constraint: `constraints/Basys3_tp_final_cp2102.xdc`.
- Cableado: `CP2102 TXD -> JA1/J1`, `CP2102 RXD <- JA2/L2` y masa común.
- Configuración: niveles lógicos de 3,3 V, 115200 baud, 8N1 y sin control de flujo.
- Bitstream: `output/bitstream/top_tp_final_90mhz_cp2102.bit`.
- SHA-256: `B9DD2EF17BDD42254F592905F4406A29CBD9B2F0690E0DFC4858AD0FA278848F`.
- Implementación: completada sin errores; bitgen y enrutado aprobados, con 0 redes fallidas.
- Timing post-route: WNS `+0.353 ns`, TNS `0.000 ns`, WHS `+0.056 ns` y THS `0.000 ns`.
- DRC: 0 observaciones.
- Utilización: 2477 LUT, 2207 registros y 2 BRAM36.
- Reportes: `timing_90mhz_cp2102.rpt`, `utilization_90mhz_cp2102.rpt` y `drc_90mhz_cp2102.rpt` dentro de `reports/final/`.
- Validación física mediante el puerto COM del CP2102: pendiente.
