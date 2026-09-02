# Informe trabajo práctico nº 1 de arquitectura de computadoras 2026
### Profesor: Alonso Pereyra Martín
###  Estudiantes: Potinski Mijail Andrés, Cisneros Tomás Alejo.

<br>

## 1. Objetivos y consignas
Implementar la ALU en FPGA. <br>
Las entradas de bus de datos deben ser parametrizables. <br>
Validar desarrollo mediante un test bench. <br>



## 2. Descripción general del diseño
El diseño presentado por el profe para la implementación cuenta de 2 buses de datos de entrada
parametrizables los cuales permitiran el reuso de este diseño para los trabajos posteriores.
La carga de estos sera mediante el uso de los switches de la placa (Basys 3) y estos seran mantenidos
junto con la entrada de código de operación por unos flip flop D.  <br>
Una ALU (unidad lógica aritmetica) la cual cuenta con 8 operaciones diferentes que se pueden
realizar con los datos.   <br>
Y a la salida el resultado será mostrado en los leds de la placa, posicionados sobre los swithches.
<img width="883" height="644" alt="image" src="https://github.com/user-attachments/assets/56a8d3ef-5268-4ab3-b3db-1794d047e4f0" />
<br> <br>
Las operaciones soportadas por la ALU con sus respectivos códigos son:
```
ADD    100000
SUB    100010
AND    100100
OR     100101
XOR    100110
SRA    000011
SRL    000010
NOR    100111
```


## 3. Arquitectura implementada
### 3.1. Módulo ALU

La ALU es un módulo combinacional que recibe dos operandos, `A` y `B`, junto con un código de operación que determina qué cálculo realizar. Según ese código, puede ejecutar suma, resta, operaciones lógicas como AND, OR, XOR y NOR, o desplazamientos a derecha. El resultado se entrega en `C`, mientras que las señales `zero`, `carry` y `overflow` informan condiciones especiales del resultado. Para suma y resta se utiliza una variable auxiliar de un bit extra, que permite detectar el acarreo. Como es lógica combinacional, cada vez que cambia alguna entrada se recalculan inmediatamente el resultado y las banderas.

```verilog
MÓDULO ALU

Entradas:
    A
    B
    operación

Salidas:
    C
    zero
    carry
    overflow

Variable auxiliar:
    aux  // un bit más que A y B para detectar carry

Siempre que cambie alguna entrada:

    Inicializar:
        C = 0
        carry = 0
        overflow = 0
        aux = 0

    Según operación:

        ADD:
            aux = A + B
            C = resultado
            carry = bit extra de aux
            calcular overflow

        SUB:
            aux = A - B
            C = resultado
            carry = bit extra de aux
            calcular overflow

        AND:
            C = A AND B

        OR:
            C = A OR B

        XOR:
            C = A XOR B

        SRA:
            C = desplazamiento aritmético a derecha de A

        SRL:
            C = desplazamiento lógico a derecha de A

        NOR:
            C = NOT(A OR B)

        DEFAULT:
            C = 0

    Si C == 0:
        zero = 1
    sino:
        zero = 0
```


### 3.2. Módulo reg_nbits 
Este modela los flip flop que se encargar de mantener la informacion de entrada tanto de los dos 
buses de datos como del codigo de operacion.

```verilog
MÓDULO reg_nbits

Parámetro:
    NB_BITS = cantidad de bits del registro

Entradas:
    clk
    enable
    D

Salida:
    Q

Al inicio:
    Q = 0

En cada flanco ascendente del clock:
    si enable = 1:
        Q = D
    si enable = 0:
        Q mantiene su valor anterior
```

Tenemos dos señales de entrada y ambos buses parametrizables de entrada y salida.
La señal de clock para sincronizar el FF, el enable para activarlo y guardar el dato que tiene
en la entrada en los switch.
Dentro del bloque always tenemos configurado para que funcione con el clock en flanco ascendente y
en caso de estar también la señal de enable mapeada a un botón se tomara la entrada de los swithches y 
estará guardada en la salida del FF y entrada de la ALU.


### 3.3. Módulo Top

El módulo top es el encargado de integrar todo el sistema. Recibe el reloj, los switches y los botones, y utiliza tres instancias del mismo módulo de registro parametrizable. Dos de esas instancias, REG_A y REG_B, están configuradas para almacenar operandos de 8 bits, mientras que REG_OP está configurado para guardar un código de operación de 6 bits. La ventaja de usar un registro parametrizable es que se reutiliza el mismo diseño de hardware cambiando únicamente el ancho de los datos que debe almacenar.

Los valores se ingresan mediante los switches y cada botón habilita la carga de un registro distinto: un botón carga A, otro carga B y otro carga la operación. Luego, las salidas de esos registros se conectan a la ALU. La ALU toma A, B y el código de operación, realiza la operación correspondiente y entrega el resultado en los LEDs, junto con las señales de estado zero, carry y overflow.

```verilog
MÓDULO TOP

Parámetro:
    NB_BITS = 8

Entradas:
    clk
    switches
    botón A
    botón B
    botón OP

Salidas:
    leds
    zero
    carry
    overflow

Señales internas:
    A
    B
    op

Instanciar REG_A:
    ancho = NB_BITS
    si botón A está activo en un flanco de clk:
        guardar switches en A

Instanciar REG_B:
    ancho = NB_BITS
    si botón B está activo en un flanco de clk:
        guardar switches en B

Instanciar REG_OP:
    ancho = 6
    si botón OP está activo en un flanco de clk:
        guardar los 6 bits menos significativos de switches en op

Instanciar ALU:
    entrada A = A
    entrada B = B
    operación = op

    resultado -> leds
    zero -> o_zero
    carry -> o_carry
    overflow -> o_overflow

```

## 4. Operaciones implementadas



## 5. Implementación sobre Basys 3
# Esquemático

<img width="1762" height="916" alt="image" src="https://github.com/user-attachments/assets/11107f98-3289-4e47-a204-5158d432bd5e" />

<img width="2592" height="942" alt="image" src="https://github.com/user-attachments/assets/bd669914-6bb0-4e04-ae40-fe377f450131" />


### 5.1. Carga de operandos
### 5.2. Selección de operación
### 5.3. Visualización del resultado y flags

## 6. Verificación
### 6.1. Testbench
### 6.2. Pruebas dirigidas
### 6.3. Pruebas aleatorias
### 6.4. Resultados de simulación

## 7. Síntesis e implementación

## 8. Análisis temporal
El análisis temporal realizado en Vivado muestra que todas las restricciones temporales se cumplen, sin violaciones de setup (dato que llega demasiado tarde al flip-flop) ni hold (dato que cambia demasiado rápido después del flanco). No se registraron endpoints fallidos y el diseño presenta un margen positivo en el ancho de pulso, por lo que puede implementarse correctamente con el reloj definido.
<img width="969" height="253" alt="image" src="https://github.com/user-attachments/assets/b8a16f45-1e4e-48cb-af5a-cf11c4a46766" />

El valor obtenido WPWS = 4,5 ns, nos indica que en el peor caso de ancho de pulso todavía posee un margen positivo de 4,5 ns respecto del mínimo requerido por la FPGA.


## 9. Conclusiones


