# Informe trabajo práctico nº 1 de arquitectura de computadoras 2026
### Profesor: Alonso Pereyra
###  Estudiantes: Potinski Mijail Andrés, Cisneros Alejo Tomás.

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



## 3. Arquitectura implementada
### 3.1. Módulo ALU
### 3.2. Módulo flip flop D
### 3.3. Módulo Top

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


