# TP final - RISC-V pipeline con Debug Unit

Proyecto para Basys 3 (`xc7a35tcpg236-1`) desarrollado con Vivado 2025.2.

La ALU RV32, el banco de registros, el decoder/inmediatos, las memorias Harvard y el pipeline IF/ID/EX/MEM/WB con forwarding, bypass WB-ID y stalls `load-use` ya fueron validados en placa. También se verificaron físicamente las 32 instrucciones RV32I exigidas, el control UART de `Run`, `Step`, `Pause`, `Resume` y `Reset`, y el snapshot completo del pipeline.

## Estado actual

- **Hardware:** frecuencia final de 90 MHz mediante MMCM desde los 100 MHz de la Basys 3; IMEM y DMEM de 4 KiB cada una, sin caché. Escrituras en flanco positivo y lecturas en flanco negativo.
- **Implementación USB-UART integrada:** timing post-route cumplido (WNS `+0.376 ns`, TNS `0.000 ns`), DRC sin observaciones, 2477 LUT, 2207 registros y 2 BRAM36. El snapshot completo fue validado físicamente a 90 MHz.
- **Software:** cliente Python reutilizable y GUI PySide6 con carga `.asm/.s/.hex/.bin`, controles de ejecución, registros, DMEM, pipeline desensamblado y exportación JSON. Las pruebas automáticas del software y el arranque Qt en modo offscreen están aprobados; el cliente común también fue probado en placa.
- **Pendientes:** validación visual/interactiva de la GUI y de la carga desde ensamblador con la placa, y validación física de la variante CP2102. Esta última ya tiene bitstream, timing cumplido y DRC sin observaciones.

El detalle de las pruebas y sus resultados está en [docs/VALIDACION.md](docs/VALIDACION.md). El diseño y las decisiones previstas están en [PLAN_ARQUITECTURA.md](PLAN_ARQUITECTURA.md); algunas secciones del plan describen objetivos aún pendientes y no deben tomarse como confirmación de implementación.

Los comandos de este README se ejecutan desde la carpeta raíz `tp_final`. En los ejemplos, reemplazar `COM7` por el puerto asignado al adaptador utilizado.

## Crear el proyecto de Vivado

Desde PowerShell:

```powershell
& 'C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat' `
  -mode batch -nolog -nojournal `
  -source .\scripts\create_project.tcl
```

El proyecto generado queda por defecto en `vivado/pipeline_test/tp_final.xpr`, el proyecto de trabajo conservado tras la consolidación. El script Tcl permite recrearlo desde las fuentes. Si se define la variable de entorno `TP_FINAL_VIVADO_DIR`, el script de creación usa esa carpeta como destino.

## Simulaciones

```powershell
& 'C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat' `
  -mode batch -nolog -nojournal `
  -source .\scripts\run_uart_sim.tcl
```

Regresión de la UART reutilizada:

```text
RESULTADO: TODOS LOS TESTS PASARON
UART_SIMULATION_COMPLETE
```

Prueba unitaria de la ALU:

```powershell
& 'C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat' `
  -mode batch -nolog -nojournal `
  -source .\scripts\run_alu_sim.tcl
```

Prueba de integración UART-ALU:

```powershell
& 'C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat' `
  -mode batch -nolog -nojournal `
  -source .\scripts\run_alu_uart_sim.tcl
```

Prueba unitaria del banco de registros:

```powershell
& 'C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat' `
  -mode batch -nolog -nojournal `
  -source .\scripts\run_register_file_sim.tcl
```

Prueba de integración UART-banco de registros:

```powershell
& 'C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat' `
  -mode batch -nolog -nojournal `
  -source .\scripts\run_register_file_uart_sim.tcl
```

Los resultados esperados son `RESULTADO: BANCO DE REGISTROS RV32 OK` y
`RESULTADO: INTEGRACION UART-BANCO RV32 OK`.

Prueba unitaria del decoder y generador de inmediatos:

```powershell
& 'C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat' `
  -mode batch -nolog -nojournal -notrace `
  -source .\scripts\run_decoder_sim.tcl
```

Prueba de integración UART-decoder:

```powershell
& 'C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat' `
  -mode batch -nolog -nojournal -notrace `
  -source .\scripts\run_decoder_uart_sim.tcl
```

Los resultados esperados son `RESULTADO: DECODER E INMEDIATOS RV32I OK` y
`RESULTADO: INTEGRACION UART-DECODER RV32I OK`.

Prueba unitaria de IMEM y DMEM:

```powershell
& 'C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat' `
  -mode batch -nolog -nojournal -notrace `
  -source .\scripts\run_memory_sim.tcl
```

Prueba de integración UART-memorias:

```powershell
& 'C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat' `
  -mode batch -nolog -nojournal -notrace `
  -source .\scripts\run_memory_uart_sim.tcl
```

Los resultados esperados son `RESULTADO: MEMORIAS RV32 OK` y
`RESULTADO: INTEGRACION UART-MEMORIAS RV32 OK`.

Prueba del pipeline con hazards:

```powershell
& 'C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat' `
  -mode batch -nolog -nojournal -notrace `
  -source .\scripts\run_pipeline_sim.tcl
```

Prueba de cobertura de las 32 instrucciones obligatorias:

```powershell
& 'C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat' `
  -mode batch -nolog -nojournal -notrace `
  -source .\scripts\run_pipeline_rv32i_sim.tcl
```

Prueba extremo a extremo UART-pipeline con la misma imagen:

```powershell
& 'C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat' `
  -mode batch -nolog -nojournal -notrace `
  -source .\scripts\run_pipeline_uart_sim.tcl
```

Los resultados esperados incluyen `RESULTADO: PIPELINE RV32 HAZARDS OK`,
`RESULTADO: COBERTURA RV32I PIPELINE OK` y
`RESULTADO: INTEGRACION UART-PIPELINE RV32I OK`.

## Síntesis

```powershell
& 'C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat' `
  -mode batch -nolog -nojournal `
  -source .\scripts\run_synthesis.tcl
```

Los reportes de síntesis quedan en `reports/final/synthesis_utilization_90mhz.rpt` y `reports/final/synthesis_timing_90mhz.rpt`. El cierre de timing final se verifica con los reportes post-route generados al implementar el bitstream.

## Generar bitstream

```powershell
& 'C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat' `
  -mode batch -nolog -nojournal -notrace `
  -source .\scripts\run_pipeline_bitstream.tcl
```

La variante para el USB-UART integrado queda en
`output/bitstream/top_tp_final_90mhz.bit`.
El script también genera `timing_90mhz.rpt`, `utilization_90mhz.rpt` y `drc_90mhz.rpt` dentro de `reports/final/`.

### Generar la variante para CP2102

```powershell
& 'C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat' `
  -mode batch -nolog -nojournal -notrace `
  -source .\scripts\run_pipeline_cp2102_bitstream.tcl
```

El resultado queda en
`output/bitstream/top_tp_final_90mhz_cp2102.bit`. Esta variante conserva el
mismo RTL, reloj interno de 90 MHz y protocolo UART de 115200 baud, pero mueve
RX/TX al Pmod JA:

| CP2102 | Basys 3 | Pin FPGA |
| --- | --- | --- |
| `TXD` | `JA1` | `J1`, entrada `i_uart_rx` |
| `RXD` | `JA2` | `L2`, salida `o_uart_tx` |
| `GND` | GND del Pmod JA | masa común |

Las señales TX/RX se conectan cruzadas. El CP2102 debe usar niveles lógicos de
3,3 V; no conectar `5V` ni `VCC` del adaptador a la Basys 3. La placa continúa
alimentada y programada por su USB habitual. En la GUI se selecciona el puerto
COM que Windows asigne al CP2102.

La variante CP2102 cumple timing a 90 MHz (WNS `+0.353 ns`, TNS `0.000 ns`) y tiene DRC sin observaciones. Su validación física con este TP sigue pendiente; los reportes se guardan en `reports/final/` con sufijo `_90mhz_cp2102.rpt`.

## Probar la cobertura RV32I en placa

- Top: `top_tp_final`.
- Clock interno: 90 MHz generado por MMCM desde los 100 MHz de la placa.
- UART: 115200 baud, 8N1.
- Reset: botón central `BTNC`.
- USB-UART integrado: `B18` para RX y `A18` para TX.
- `LED7`: core detenido.
- `LED6`: core ejecutando.
- `LED5:LED2`: causa de parada.
- `LED1:LED0`: validez de las dos etapas más jóvenes.
- `LED11`: overrun de recepción.
- `LED12`: error de frame.

Después de programar la FPGA, presionar `BTNC` y ejecutar:

```powershell
py -m pip install pyserial
py .\sw\client\rv32i_coverage_test.py COM7
```

Reemplazar `COM7` por el puerto de la Basys 3. El cliente carga 52 palabras sin `nop` y ejecuta las 32 instrucciones exigidas: operaciones R e inmediatas, loads y stores byte/half/word, extensión signed/unsigned, `beq`, `bne`, `lui`, `jal`, `jalr` y `ebreak`. Comprueba los 32 registros, DMEM, 56 ciclos, 43 instrucciones retiradas y el pipeline vacío. El resultado esperado termina con:

```text
RESULTADO: COBERTURA RV32I COMPLETA EN PLACA OK
```

La arquitectura y las decisiones completas están en `PLAN_ARQUITECTURA.md`.

## Probar el control de ejecución

Después de programar `top_tp_final_90mhz.bit`, presionar `BTNC` y ejecutar:

```powershell
py .\sw\client\execution_control_test.py COM7
```

La prueba valida arranque pausado, un ciclo exacto por `Step`, lectura de registros y DMEM durante la pausa, rechazo de pasos después de `HALT`, congelamiento de un loop, `Resume` y limpieza del estado mediante `Reset`. El resultado esperado termina con:

```text
RESULTADO: RUN STEP PAUSE RESUME RESET EN PLACA OK
```

## Probar el snapshot del pipeline

Programar `top_tp_final_90mhz.bit`, presionar `BTNC` y ejecutar:

```powershell
py .\sw\client\pipeline_snapshot_test.py COM7
```

El cliente carga cuatro instrucciones, avanza cuatro ciclos y comprueba una captura con las cuatro etapas ocupadas. Muestra PC, instrucción, operandos, inmediato, resultados y control de IF/ID, ID/EX, EX/MEM y MEM/WB. El resultado esperado termina con:

```text
RESULTADO: SNAPSHOT COMPLETO DEL PIPELINE EN PLACA OK
```

## Abrir la interfaz gráfica

Instalar las dependencias y ejecutar:

```powershell
py -m pip install --user -r .\sw\requirements.txt
py .\sw\gui\tp_final_gui.py
```

En la ventana:

1. Seleccionar el puerto COM de la placa o del CP2102 y presionar **Conectar**.
2. Elegir `sw\programs\pipeline_demo.asm` mediante **Examinar** (también se admite el `.hex` existente).
3. Presionar **Cargar programa**. El core queda pausado y listo para avanzar.
4. Presionar **Step** cuatro veces: las cuatro etapas deben quedar con `valid=1` y mostrar `ebreak`, `sw` y los dos `addi` del demo.
5. Continuar con **Step** hasta `Detenido`, o usar **Reset** para volver al estado inicial.
6. Para probar ejecución continua, cargar `sw\programs\loop_demo.hex`, presionar **Run** y luego **Pause**. Los contadores deben quedar estables; **Step** debe avanzar un ciclo y **Resume** debe reanudar el loop.
7. Usar **Actualizar estado** para leer registros, las primeras 16 palabras de DMEM y el snapshot del pipeline.

La comunicación serie corre en un hilo separado de Qt. Los botones se habilitan según el estado real del procesador y **Exportar snapshot** guarda en JSON la captura, registros y memoria visibles.

Este recorrido sirve como guía para la validación visual/interactiva pendiente. La GUI admite fuentes `.asm/.s`, que se ensamblan antes de enviarse por UART, además de imágenes `.hex/.bin`. La traducción tiene pruebas automáticas aprobadas; falta validar este recorrido con la placa.

## Carga desde ensamblador

El ensamblador Python de dos pasadas soporta las 32 instrucciones requeridas,
etiquetas, registros ABI, inmediatos, `.word`, `nop` y `halt`. La GUI muestra
los errores con número de línea y solo envía el programa si la traducción es válida.

Para generar `.hex`, `.bin` y `.map` desde la raíz del proyecto:

```powershell
py .\sw\client\rv32i_assembler.py .\sw\programs\pipeline_demo.asm
```

Ejemplos adicionales: `sw/programs/load_use_demo.asm` y `sw/programs/labels_demo.asm`.
La sintaxis, los límites y las pruebas se describen en [ENSAMBLADOR.md](ENSAMBLADOR.md).

## Estructura final de artefactos

- `output/bitstream/top_tp_final_90mhz.bit`: variante USB-UART integrada.
- `output/bitstream/top_tp_final_90mhz_cp2102.bit`: variante CP2102 por JA1/JA2.
- `reports/final/`: timing, utilización y DRC de ambas implementaciones.
- `vivado/pipeline_test/tp_final.xpr`: proyecto de trabajo de Vivado.
- `docs/VALIDACION.md`: registro de pruebas simuladas, implementaciones y validaciones físicas.
- `rtl/`: procesador, memorias, UART y Debug Unit.
- `sim/`: testbenches unitarios e integrados conservados para regresión.
- `sw/client/`: cliente UART y herramientas de prueba.
- `sw/gui/`: interfaz gráfica.
- `sw/programs/`: programas `.hex` de demostración.
- `sw/tests/`: pruebas automáticas del software.
