# Informe de trabajo práctico Nº 2 de arquitectura de computadoras 2026
### Profesor: Alonso Pereyra Martín
###  Estudiantes: Potinski Mijail Andrés, Cisneros Tomás Alejo.

<br>

## 1. Objetivos y consignas
Implementar conexión UART para conectarnos con la ALU a la pc en la FPGA. <br>







## 5. Implementación sobre Basys 3

## 5.1. Esquemático
<img width="2270" height="997" alt="image" src="https://github.com/user-attachments/assets/2489b480-bb15-4c9c-99bd-5f546b1a0dbb" />

<img width="1326" height="1027" alt="image" src="https://github.com/user-attachments/assets/16dc8733-6570-4ea4-a0cb-941158765ca0" />

<img width="2380" height="1024" alt="image" src="https://github.com/user-attachments/assets/cbbaa855-4ab2-4bf3-9015-bc978a1b6341" />

<img width="2214" height="1012" alt="image" src="https://github.com/user-attachments/assets/c26cab65-9985-4112-9834-64ffefa4eb31" />





## 7. Análisis temporal
El análisis temporal realizado en Vivado muestra que todas las restricciones temporales se cumplen, sin violaciones de setup (dato que llega demasiado tarde al flip-flop) ni hold (dato que cambia demasiado rápido después del flanco). No se registraron endpoints fallidos y el diseño presenta un margen positivo en el ancho de pulso, por lo que puede implementarse correctamente con el reloj definido.

<img width="934" height="217" alt="image" src="https://github.com/user-attachments/assets/3c9d1960-d179-4871-b488-74d4fff31d67" />

El valor obtenido WPWS = 4,5 ns, nos indica que en el peor caso de ancho de pulso todavía posee un margen positivo de 4,5 ns respecto del mínimo requerido por la FPGA.






## 666. Pruebas en placa


https://github.com/user-attachments/assets/f8cefe6b-41c8-45ba-811f-dfc6756e5fc6





