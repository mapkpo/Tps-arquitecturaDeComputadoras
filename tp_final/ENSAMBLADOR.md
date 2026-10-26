# Carga desde ensamblador

El software traduce archivos `.asm` y `.s` (incluido `.S`) al subconjunto RV32I
implementado en el procesador. No requiere instalar herramientas adicionales.

## Desde la GUI

1. Reiniciar la GUI si estaba abierta al instalar esta version.
2. Conectar al puerto de la placa.
3. Elegir `sw/programs/pipeline_demo.asm` con **Examinar**.
4. Pulsar **Cargar programa**. Primero se ensambla y luego se envia por UART.
5. Usar **Step** o **Run**. Resultado del demo: x1=1, x2=3 y DMEM[0]=3.

Un error de ensamblado muestra la linea y no envia comandos a la placa.
La GUI ensambla en memoria; no genera archivos de salida automaticamente.
Tambien se pueden cargar los archivos `.hex/.bin` existentes.

## Generar archivos para la entrega

Desde la raiz `tp_final`:

```powershell
py .\sw\client\rv32i_assembler.py .\sw\programs\pipeline_demo.asm
```

Genera junto al fuente `.hex` (palabras hexadecimales), `.bin` (bytes
little-endian) y `.map` (direcciones, instrucciones, lineas y etiquetas).
Para elegir otro nombre de salida, agregar `-o ruta\salida.hex`.
Si esos archivos ya existen, se reemplazan; el fuente se conserva.

## Sintaxis admitida

- Registros `x0` a `x31` y nombres ABI (`zero`, `ra`, `sp`, `a0`, etc.; `fp=s0`).
- Inmediatos decimales, negativos o hexadecimales con prefijo `0x`.
- Operandos separados por comas. Instrucciones y registros sin distincion
  entre mayusculas y minusculas; las etiquetas si distinguen mayusculas.
- Comentarios con `#`, `;` o `//`.
- Etiquetas hacia adelante y hacia atras; no se admiten expresiones ni macros.
- `.word valor`: emite una palabra de 32 bits, sin validar su instruccion.
- `nop`: `addi x0,x0,0`. `halt`: `ebreak`.
- Se exige al menos un `halt`/`ebreak` explicito (tambien puede codificarse con
  `.word 0x00100073`). Esto no garantiza que todos los caminos lo alcancen.

Instrucciones soportadas:

```text
add sub sll srl sra and or xor slt sltu
addi andi ori xori slti sltiu slli srli srai
lb lh lw lbu lhu sb sh sw
beq bne lui jal jalr ebreak
```

Ejemplos:

```asm
    addi x1, x0, 4
loop:
    addi x1, x1, -1
    bne x1, x0, loop
    halt
```

`beq rs1,rs2,etiqueta`, `bne rs1,rs2,etiqueta` y `jal rd,etiqueta`
calculan el desplazamiento respecto del PC de la propia instruccion. Si se
escribe un numero en lugar de una etiqueta, representa un desplazamiento en
bytes, no una direccion absoluta. Los destinos deben estar alineados a 4 bytes
porque este procesador no implementa instrucciones comprimidas.

Loads/stores usan `lw rd,offset(rs1)` / `sw rs2,offset(rs1)`.
`jalr` admite `jalr rd,offset(rs1)` o `jalr rd,rs1,offset`.
`lui rd,0x12345` produce el valor `0x12345000`.

Se validan registros, numero de operandos, etiquetas, rangos de inmediatos,
desplazamientos de 0 a 31 bits y limite de 1024 palabras (4 KiB de IMEM).
La alineacion y el rango de direcciones calculadas a partir de registros
(loads/stores y jalr) se comprueban durante la ejecucion por el hardware.
No es un ensamblador RISC-V completo: no soporta otras instrucciones,
secciones `.text/.data`, relocaciones ni pseudoinstrucciones como `li`.

## Pruebas

```powershell
py -m unittest discover -s sw/tests -v
```

Se verificaron las 52 palabras del programa `sim/programs/rv32i_coverage.S`
contra la imagen ya utilizada para validar las 32 instrucciones en placa,
ademas de saltos negativos, limites, errores, salidas de CLI y carga desde GUI.
Las 14 pruebas de software pasaron. La carga del fuente desde la GUI con la
placa conectada queda pendiente de verificacion fisica.
