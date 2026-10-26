# Guía para escribir programas en ensamblador — TP RV32I

Esta guía describe las **32 instrucciones implementadas en el TP**, más `ebreak`,
las pseudoinstrucciones y la directiva que admite nuestro ensamblador. Los
ejemplos completos se pueden guardar como `.asm` y cargar desde la GUI.

## 1. Cómo empezar

1. Crear un archivo de texto, por ejemplo `mi_programa.asm` (no `.asm.txt`).
2. Escribir una instrucción por línea, con operandos separados por comas.
3. Incluir `halt` para terminar.
4. En la GUI, seleccionar el archivo con **Examinar** y pulsar **Cargar programa**.
5. Ejecutar con **Run** o avanzar con **Step**. Un Step avanza un ciclo, no una instrucción completa.

Programa mínimo:

```asm
addi x1, x0, 1    # x1 = 1
addi x2, x1, 2    # x2 = 3
sw   x2, 0(x0)   # Guarda 3 en la dirección 0 de DMEM
halt
```

Resultado al terminar: `x1=1`, `x2=3`, palabra de memoria en dirección `0` igual a `3`.

## 2. Registros, números y sintaxis

### Qué significan los operandos

| Nombre de esta guía | Significado |
| --- | --- |
| `rd` | Registro destino: recibe el resultado. |
| `rs1`, `rs2` | Registros fuente: aportan datos. |
| `imm` | Inmediato: número escrito dentro de la instrucción. |
| `offset(base)` | Dirección de memoria: contenido de `base` más `offset` bytes. |
| `etiqueta` | Nombre de una posición del programa. |
| `PC` | Dirección de la instrucción. Cada instrucción ocupa 4 bytes. |

Hay 32 registros de 32 bits, `x0` a `x31`. **x0 siempre vale cero**; las
escrituras sobre él se ignoran. Los demás pueden guardar datos o direcciones.

`x0` no es la memoria en dirección cero: `sw x2,0(x0)` modifica memoria,
no el registro x0.

Los nombres ABI son alias de los mismos registros, no registros adicionales:

| Registros | Alias |
| --- | --- |
| x0–x4 | zero, ra, sp, gp, tp |
| x5–x7 | t0, t1, t2 |
| x8–x9 | s0 (también fp), s1 |
| x10–x17 | a0–a7 |
| x18–x27 | s2–s11 |
| x28–x31 | t3–t6 |

Para aprender, podés usar `x1`, `x2`, etc. Si escribís subrutinas, reservá
`ra/x1` para la dirección de retorno. El nombre `sp` no inicializa una pila:
si la necesitás, tenés que preparar su valor y manejarla en tu programa.

### Números y comentarios

- Decimal: `10`, `42`, `-8`. Hexadecimal: `0x2A`, `0xff`, `-0x10`.
- En un `.asm`, `10` significa diez; en un `.hex`, `10` es una palabra hexadecimal.
- Comentarios: `# comentario`, `; comentario` o `// comentario`.
- Instrucciones y registros admiten mayúsculas o minúsculas.
- Las etiquetas distinguen mayúsculas: `loop` y `Loop` son nombres distintos.
- No se admiten expresiones como `4+8` o `etiqueta+4`: usar un número o una etiqueta donde corresponda.

### Números con signo

Un registro contiene bits; la instrucción determina cómo interpretarlos.
`0xFFFFFFFF` representa `4294967295` sin signo o `-1` con signo.
Sumas y restas conservan los 32 bits bajos: no generan una excepción por overflow.

## 3. Operaciones entre registros — 10 instrucciones

Formato: `operación rd, rs1, rs2`.

| Instrucción | Qué hace | Ejemplo |
| --- | --- | --- |
| `add` | Suma: rd = rs1 + rs2. | `add x3,x1,x2` |
| `sub` | Resta: rd = rs1 − rs2. | `sub x3,x1,x2` |
| `and` | AND bit a bit. Un bit vale 1 si ambos valen 1. | `and x3,x1,x2` |
| `or` | OR bit a bit. Un bit vale 1 si alguno vale 1. | `or x3,x1,x2` |
| `xor` | XOR bit a bit. Un bit vale 1 si son diferentes. | `xor x3,x1,x2` |
| `sll` | Desplaza rs1 a la izquierda; introduce ceros. | `sll x3,x1,x2` |
| `srl` | Desplaza rs1 a la derecha; introduce ceros. | `srl x3,x1,x2` |
| `sra` | Desplaza rs1 a la derecha; repite el bit de signo. | `sra x3,x1,x2` |
| `slt` | rd = 1 si rs1 < rs2 **con signo**; si no, 0. | `slt x3,x1,x2` |
| `sltu` | rd = 1 si rs1 < rs2 **sin signo**; si no, 0. | `sltu x3,x1,x2` |

En `sll/srl/sra`, la cantidad de posiciones son los **5 bits bajos de rs2**.
Por ejemplo, un rs2 de 32 provoca un desplazamiento de 0 posiciones.

Ejemplo de signo y desplazamientos:

```asm
addi x1, x0, -8
addi x2, x0, 1
sra  x3, x1, x2   # -4 = 0xFFFFFFFC
srl  x4, x1, x2   # 0x7FFFFFFC: entra un cero a la izquierda
slt  x5, x1, x2   # 1: -8 < 1
sltu x6, x1, x2   # 0: 0xFFFFFFF8 sin signo es mayor que 1
halt
```

## 4. Operaciones con inmediatos — 9 instrucciones

Formato: `operación rd, rs1, imm`.

| Instrucción | Qué hace | Ejemplo |
| --- | --- | --- |
| `addi` | Suma una constante; con una constante negativa, resta. | `addi x1,x1,-1` |
| `andi` | AND con una constante. | `andi x2,x1,0xff` conserva los 8 bits bajos. |
| `ori` | OR con una constante. | `ori x2,x1,1` pone el bit 0 en uno. |
| `xori` | XOR con una constante. | `xori x2,x1,-1` invierte todos los bits. |
| `slti` | Comparación «menor que» con signo; devuelve 0 o 1. | `slti x2,x1,10` |
| `sltiu` | Comparación «menor que» sin signo; devuelve 0 o 1. | `sltiu x2,x1,10` |
| `slli` | Desplazamiento a izquierda por una cantidad fija. | `slli x2,x1,2` |
| `srli` | Desplazamiento a derecha introduciendo ceros. | `srli x2,x1,2` |
| `srai` | Desplazamiento a derecha conservando el signo. | `srai x2,x1,2` |

Para las seis primeras, el inmediato debe estar entre **−2048 y 2047**.
Se extiende con signo a 32 bits, incluso en operaciones lógicas y `sltiu`.
En `sltiu`, después de esa extensión se compara sin signo.
Para `slli/srli/srai`, la cantidad debe estar entre **0 y 31**.

Ejemplos útiles: `addi x1,x0,42` carga 42; `addi x2,x1,0` copia x1 a x2.
Para cargar constantes mayores se usa `lui` junto con `addi`, explicado más abajo.

## 5. Leer y escribir memoria — 8 instrucciones

La dirección siempre se calcula como **base + offset, en bytes**.
El offset es un inmediato entre −2048 y 2047. Una dirección mayor se puede
alcanzar poniendo parte de la dirección en el registro base.

### Lecturas (loads)

Formato: `load rd, offset(rs1)`.

| Instrucción | Cantidad leída | Cómo completa los 32 bits de rd |
| --- | --- | --- |
| `lb` | 1 byte (8 bits) | Extiende el signo. |
| `lbu` | 1 byte (8 bits) | Completa con ceros. |
| `lh` | 2 bytes (16 bits) | Extiende el signo. |
| `lhu` | 2 bytes (16 bits) | Completa con ceros. |
| `lw` | 4 bytes (32 bits) | Copia la palabra completa. |

### Escrituras (stores)

Formato: `store rs2, offset(rs1)`. **El primer registro es el dato a guardar**;
el registro entre paréntesis es la base de la dirección. No hay registro destino.

| Instrucción | Qué guarda |
| --- | --- |
| `sb` | Los 8 bits bajos de rs2. |
| `sh` | Los 16 bits bajos de rs2. |
| `sw` | Los 32 bits de rs2. |

### Direcciones y alineación

DMEM tiene 4096 bytes, con direcciones de `0` a `4095` (`0xFFF`).

- Byte: cualquier dirección dentro de DMEM.
- Halfword: dirección múltiplo de 2; última dirección inicial válida, 4094.
- Word: dirección múltiplo de 4; última dirección inicial válida, 4092.
- `sw x1,1(x0)` es desalineado. Para la segunda palabra se usa `sw x1,4(x0)`.
- Los accesos desalineados o fuera de memoria detienen el programa con una causa de error.
- El ensamblador valida el offset; la dirección efectiva se comprueba en hardware durante la ejecución.

La organización es **little-endian**: al guardar `0x12345678` en dirección 0,
los bytes de las direcciones 0, 1, 2 y 3 son `78`, `56`, `34` y `12`.
IMEM y DMEM son memorias distintas: `lw` lee datos, no instrucciones.

Ejemplo de diferencia entre `lb` y `lbu`:

```asm
addi x1, x0, -1
sw   x0, 0(x0)   # Inicializa los cuatro bytes a cero
sb   x1, 0(x0)   # Guarda 0xFF en el primer byte
lb   x2, 0(x0)   # x2 = 0xFFFFFFFF = -1
lbu  x3, 0(x0)   # x3 = 0x000000FF = 255
lw   x4, 0(x0)   # x4 = 255; los otros tres bytes siguen en cero
halt
```

## 6. Saltos condicionales — 2 instrucciones

| Instrucción | Sintaxis | Cuándo salta |
| --- | --- | --- |
| `beq` | `beq rs1,rs2,etiqueta` | Cuando ambos registros son iguales. |
| `bne` | `bne rs1,rs2,etiqueta` | Cuando son diferentes. |

Si no se cumple la condición, se ejecuta la instrucción siguiente.
No escriben ningún registro. Para comparar con cero, usar `x0`.

Las etiquetas terminan con `:` al declararse; al usarlas no llevan `:`.
El ensamblador calcula el desplazamiento desde el PC de la propia instrucción.
Si se usa un número en lugar de una etiqueta, ese número es un **desplazamiento
en bytes**, no una dirección absoluta ni una cantidad de instrucciones.
Los desplazamientos admitidos en este TP son múltiplos de 4, de −4096 a 4092.
Además, el destino ejecutado debe estar dentro del programa cargado.

Ejemplo: sumar 4 + 3 + 2 + 1.

```asm
addi x1, x0, 4
addi x2, x0, 0
loop:
    add  x2, x2, x1
    addi x1, x1, -1
    bne  x1, x0, loop
sw x2, 0(x0)
halt
```

Resultado: `x1=0`, `x2=10`, palabra de memoria en dirección 0 igual a 10.

Para «menor que», combinar `slt` o `sltu` con `bne`: primero obtener 0/1 en
un registro auxiliar y después saltar si ese resultado es distinto de x0.

## 7. Saltos incondicionales — 2 instrucciones

| Instrucción | Sintaxis | Efecto |
| --- | --- | --- |
| `jal` | `jal rd,etiqueta` | Guarda PC+4 en rd y salta a la etiqueta. |
| `jalr` | `jalr rd,offset(rs1)` | Guarda PC+4 en rd y salta a `(rs1 + offset) & ~1`. |

`jal x0,etiqueta` salta sin guardar una dirección de retorno.
Para `jal`, un operando numérico es un desplazamiento relativo en bytes;
en este TP debe ser múltiplo de 4, de −1048576 a 1048572.
`jalr` usa un offset de −2048 a 2047 y también acepta `jalr rd,rs1,offset`.
El bit 0 del destino de `jalr` se borra; aun así, el destino debe quedar
alineado a 4 bytes y dentro de la imagen cargada.

Ejemplo de llamada y retorno:

```asm
addi x5, x0, 6
jal  ra, duplicar       # ra recibe la dirección del halt
halt

duplicar:
    add  x5, x5, x5     # x5 = 12
    jalr x0, 0(ra)     # Retorna a la instrucción posterior al jal
```

Una llamada con `jal ra,...` sobrescribe ra. Las llamadas anidadas requieren
guardar el retorno anterior antes de hacer otra llamada.

## 8. Constantes grandes: LUI — 1 instrucción

`lui rd,imm20` coloca el inmediato en los bits 31:12 y deja los 12 bits bajos
en cero. Ejemplo: `lui x1,0x12345` produce `0x12345000`.

El ensamblador acepta un inmediato entre −524288 y 1048575 y usa sus 20 bits bajos.
No se escribe la constante de 32 bits completa como operando de `lui`.

```asm
lui  x1, 0x12345
addi x1, x1, 0x678     # x1 = 0x12345678

# Si los 12 bits bajos tienen su bit de signo en 1, ajustar la parte alta:
lui  x2, 0x12346
addi x2, x2, -1348     # x2 = 0x12345ABC
halt
```

El ajuste del segundo caso es necesario porque `0xABC` vale 2748 y no cabe
como inmediato positivo de `addi`. Se suma 1 a la parte alta y se usa
`2748 - 4096 = -1348` como parte baja.

## 9. Finalizar, no hacer nada y escribir palabras

| Elemento | Significado |
| --- | --- |
| `ebreak` | En este TP termina el programa: deja de incorporar instrucciones y drena el pipeline. |
| `halt` | Pseudoinstrucción que se traduce a `ebreak` (`0x00100073`). |
| `nop` | Pseudoinstrucción que se traduce a `addi x0,x0,0` (`0x00000013`). |
| `.word valor` | Directiva que coloca literalmente una palabra de 32 bits en IMEM. No es una instrucción por sí misma. |

El ensamblador exige incluir `halt`/`ebreak` (también reconoce su código emitido
con `.word`), pero no comprueba que todos los caminos del programa lo alcancen.
Al alcanzar `halt`, puede ser necesario dar más pasos para vaciar el pipeline
y llegar al estado **Detenido**.

`.word` acepta una única palabra por línea, entre −2147483648 y 4294967295.
No inicializa DMEM: para preparar datos en memoria usá instrucciones `sb/sh/sw`.
Si el procesador llega a una palabra que no codifica una instrucción válida,
se detiene por instrucción ilegal.

## 10. Dependencias: no agregar NOPs por obligación

El hardware resuelve dependencias con forwarding, bypass WB-ID y un stall
cuando una instrucción usa inmediatamente el resultado de un load.
No hace falta insertar NOPs manuales para esos casos.

```asm
addi x1, x0, 42
sw   x1, 0(x0)      # Forwarding del dato a guardar
lw   x2, 0(x0)
add  x3, x2, x2     # Un stall y luego forwarding: x3 = 84
halt
```

Para observarlo, después de 4 pasos el load está en ID/EX y el add en IF/ID.
En el paso 5 aparece una burbuja en ID/EX (`valid=0`) y se conservan PC e IF/ID.
En el paso 7 se obtiene 84 en EX/MEM. Los campos A/B de ID/EX son anteriores
al forwarding de EX: pueden mostrar un valor viejo aunque el resultado sea correcto.

## 11. Errores frecuentes y equivalencias útiles

| Situación | Qué escribir o revisar |
| --- | --- |
| Quiero cargar 42. | `addi x1,x0,42`. No se admite `li`. |
| Quiero copiar un registro. | `addi x2,x1,0`. No se admite `mv`. |
| Quiero saltar sin retorno. | `jal x0,etiqueta`. No se admite `j`. |
| Quiero volver de una subrutina. | `jalr x0,0(ra)`. No se admite `ret`. |
| Quiero multiplicar por 4. | `slli x2,x1,2` conserva los 32 bits bajos. No hay `mul`. |
| Quiero comparar con una constante en un branch. | Cargar la constante en un registro; `beq/bne` comparan dos registros. |
| Quiero la segunda palabra de memoria. | Usar dirección 4, no 1. |
| Escribí `addi x1,x0,0xFFF`. | 4095 no cabe; usar `-1` si se desea el patrón `0xFFFFFFFF`. |
| Escribí una etiqueta y no la encuentra. | Revisar nombre, mayúsculas y `:` en la declaración. |
| Copié un programa de otro ensamblador. | No se admiten `.text`, `.data`, `.globl`, macros ni todas las pseudoinstrucciones habituales. |
| El programa lee datos que no preparé. | Inicializar las posiciones necesarias mediante stores; no depender del contenido previo de DMEM. |
| La GUI muestra `valid=0`. | Los otros campos de esa etapa no representan una instrucción válida. |

El programa completo tiene un máximo de **1024 palabras**, contando instrucciones,
`nop`, `halt` y `.word`. Las etiquetas y los comentarios no ocupan memoria.

## 12. Generar archivos para revisar o entregar

Desde la carpeta `tp_final`:

```powershell
py .\sw\client\rv32i_assembler.py .\sw\programs\mi_programa.asm
```

Se generan `.hex`, `.bin` little-endian y `.map` junto al fuente. El `.map`
permite ver la dirección y el código de cada instrucción y las etiquetas.
Los archivos de salida existentes con esos nombres se reemplazan.
La GUI puede cargar el `.asm` directamente sin generar estos archivos.

Para más detalles de uso: [ENSAMBLADOR.md](ENSAMBLADOR.md).
