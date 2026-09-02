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
*C* contiene el resultado de la operación seleccionada, *zero* indica si ese resultado es, justamente, cero, *carry* señala la presencia de acarreo en operaciones aritméticas y *overflow* indica que el resultado con signo excede el rango representable.
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

Nuestro módulo top integra una ALU y tres instancias del módulo parametrizable reg_nbits. Dos instancias se usan para almacenar los operandos REG_A y REG_B, configuradas con un ancho de 8 bits, y una tercera instancia almacena REG_OP, configurada con un ancho de 6 bits. Luego, las salidas de esos registros se conectan a las entradas correspondientes de la ALU, de manera que la ALU opere con los valores previamente cargados.

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

En este modulo, las señales *C, zero, carry y overflow* forman parte de la salida de la ALU y representan el resultado y sus banderas de estado. Nuestro modulo simplemente conecta estas salidas de la ALU con las señales internas o externas correspondientes del sistema, en este caso, LEDS.

## 4. Operaciones implementadas



## 5. Implementación sobre Basys 3
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

## 9. Conclusiones


