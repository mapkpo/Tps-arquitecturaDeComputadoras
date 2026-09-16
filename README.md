# Informe de trabajo práctico Nº 2 de arquitectura de computadoras 2026
### Profesor: Alonso Pereyra Martín
###  Estudiantes: Potinski Mijail Andrés, Cisneros Tomás Alejo.

<br>

## 1. Objetivos y consignas

El objetivo del presente trabajo práctico es diseñar e implementar un sistema de comunicación serie basado en el protocolo UART (Universal Asynchronous Receiver and Transmitter), integrándolo con la ALU desarrollada previamente. Para ello se busca aplicar los conceptos de máquinas de estados finitas (FSM) al diseño de lógica secuencial, utilizando distintos estados para controlar las etapas involucradas en la recepción, procesamiento y transmisión de información.

La comunicación UART permite realizar una transferencia de datos de forma asíncrona, es decir, sin transmitir una señal de reloj junto con los datos. Por este motivo, el sistema debe generar internamente una referencia temporal a partir del reloj de la placa mediante un Baud Rate Generator, que proporciona los ticks utilizados para determinar correctamente los instantes de muestreo de cada bit recibido.

El trabajo busca además comprender la organización modular de un sistema digital de comunicación, separando las funciones de generación de temporización, recepción, transmisión e interfaz con la ALU. De esta manera, los datos recibidos en forma serial son reconstruidos en palabras de 8 bits, entregados al circuito de interfaz y utilizados para interactuar con la ALU. De manera análoga, los resultados o datos provenientes de la ALU pueden ser enviados hacia el exterior mediante el transmisor UART.


## 2. Funcionamiento del sistema

El sistema tiene como finalidad permitir la comunicación entre la ALU y un dispositivo externo mediante una interfaz UART (*Universal Asynchronous Receiver and Transmitter*). Para ello, la arquitectura se divide en diferentes bloques encargados de generar la temporización necesaria, recibir y transmitir información serial, administrar el intercambio de datos y realizar el procesamiento correspondiente en la ALU.

La comunicación UART es de tipo asíncrona, por lo que no se transmite una señal de reloj junto con los datos. En consecuencia, transmisor y receptor deben trabajar con una velocidad de comunicación previamente establecida. Los datos se envían mediante tramas formadas por un bit de inicio, los bits de información y uno o más bits de parada, pudiendo incluir además un bit de paridad de forma opcional.

La arquitectura general está compuesta por un **Baud Rate Generator**, un **receptor UART**, un **transmisor UART**, un **circuito de interfaz** y la **ALU**. La interacción entre estos bloques permite recibir información en forma serial, procesarla internamente como datos paralelos y posteriormente transmitir el resultado nuevamente en forma serial.

### Baud Rate Generator

El **Baud Rate Generator** tiene como función proporcionar la referencia temporal utilizada durante la comunicación UART.

Debido a que el protocolo UART no transmite una señal de reloj junto con los datos, el receptor debe determinar internamente los instantes en los que debe observar la línea de entrada. Para ello se genera una señal de `tick` a partir del reloj principal del sistema.

El esquema utilizado emplea un sobremuestreo de **16 veces el Baud Rate**, por lo que durante el período correspondiente a cada bit se generan 16 ticks. Por ejemplo, para una velocidad de comunicación de 19.200 baudios se requiere una frecuencia de muestreo de:

19.200 × 16 = 307.200 ticks/s

El uso de estos ticks permite establecer una referencia temporal común para controlar las distintas etapas de recepción y transmisión de las tramas UART.

### Receptor UART (Rx)

El **receptor UART** tiene como función recibir la información proveniente de la línea serial `RX` y reconstruir a partir de ella el dato transmitido.

En condición de reposo, la línea permanece en nivel lógico alto. El comienzo de una nueva trama se detecta cuando la señal pasa a nivel bajo, indicando la presencia del bit de Start. En ese momento comienza el conteo de los ticks generados por el Baud Rate Generator.

Para verificar correctamente el comienzo de la trama, el receptor espera aproximadamente la mitad del período correspondiente al bit de Start. Con un sobremuestreo de 16 veces, esto implica esperar aproximadamente 8 ticks antes de volver a observar la entrada.

Una vez validado el Start Bit, el receptor espera períodos de 16 ticks para desplazarse aproximadamente hasta el centro de cada uno de los bits siguientes. En esos instantes se toma el valor presente en la entrada y se incorporan progresivamente los bits recibidos hasta reconstruir la palabra completa.

Una vez recibidos los bits de datos, el receptor continúa con la parte final de la trama, correspondiente al bit de Stop. Finalizada correctamente esta secuencia, el dato queda disponible en forma paralela para ser utilizado por el resto del sistema.

El proceso de recepción puede resumirse como:

`Reposo → detección de Start → validación de Start → recepción de datos → Stop → dato disponible`

![Estructura de una trama UART](images/trama-uart.png)

*Figura 1. Estructura general de una trama UART compuesta por bit de Start, bits de datos, paridad opcional y bit(s) de Stop.*


### Interfaz

El **modulo de interfaz** actúa como intermediario entre el subsistema UART y la ALU. Su función principal es coordinar el intercambio de datos entre ambos bloques, desacoplando la comunicación serial de la forma de trabajo interna del sistema.

El receptor y el transmisor UART se encargan de convertir la información entre una representación serial y una representación paralela. A partir de ese punto, la comunicación con el circuito de interfaz se realiza mediante palabras de datos y señales de control que indican cuándo existe información disponible y cuándo puede realizarse una transferencia.

En el camino de recepción intervienen las señales `r_data`, `rx_empty` y `rd`. La señal `r_data` contiene el byte recibido por UART, mientras que `rx_empty` indica si existe o no un dato pendiente de lectura. Cuando `rx_empty` se encuentra activa, no hay información disponible; cuando se desactiva, el dato presente en `r_data` puede ser leído por la interfaz. Una vez utilizado dicho dato, la interfaz activa `rd` para indicar que la lectura fue realizada y que el receptor puede liberar ese dato y quedar a la espera de uno nuevo.

Por lo tanto, el intercambio en recepción puede representarse conceptualmente como:

`dato recibido → rx_empty = 0 → lectura de r_data → rd → rx_empty = 1`

En el camino de transmisión se utilizan las señales `w_data`, `wr` y `tx_full`. La señal `w_data` contiene el byte que la interfaz desea transmitir. Antes de entregarlo, la interfaz verifica `tx_full`, que indica si el sistema de transmisión puede aceptar un nuevo dato. Cuando existe espacio disponible, el dato se coloca sobre `w_data` y se activa `wr`, indicando que debe ser tomado para su posterior transmisión mediante `TX`.

El intercambio en transmisión puede resumirse como:

`tx_full = 0 → colocar dato en w_data → wr → transmisión UART`

Estas señales constituyen un mecanismo de sincronización entre bloques: la interfaz no necesita conocer en qué bit de una trama se encuentra el receptor o el transmisor, sino únicamente si existe un dato disponible para leer o si puede entregar uno nuevo para transmitir.

Internamente, el receptor informa la finalización de una trama mediante `rx_done` y entrega el dato recibido. De manera análoga, el transmisor recibe una orden de inicio mediante `tx_start` y utiliza `tx_done` para indicar que la transmisión ha finalizado. De esta forma, el circuito UART encapsula los detalles temporales propios de la comunicación serial y presenta hacia la interfaz un mecanismo de transferencia basado en palabras completas.



![Diagrama Baud Rate Generator, receptor e interfaz](images/baud-receptor-infertace.png)

*Figura 1. Diagrama del Baud Rate Generator, receptor UART y circuito de interfaz.*

### Transmisor UART (Tx)

El **transmisor UART** cumple la función complementaria al receptor: toma un dato disponible internamente en forma paralela y permite enviarlo hacia el exterior mediante la línea serial `TX`.

Para realizar la transmisión, el dato debe incorporarse dentro de una trama UART. La línea se mantiene inicialmente en estado lógico alto y, al comenzar una nueva transmisión, se genera el bit de Start llevando la señal a nivel bajo.

A continuación se transmiten los bits correspondientes al dato y finalmente se genera el bit de Stop, retornando la línea al nivel lógico alto.

La duración de cada una de estas etapas queda determinada por la referencia temporal generada por el Baud Rate Generator.

De esta forma, el transmisor permite convertir los datos utilizados internamente por el sistema en la secuencia serial necesaria para realizar la comunicación UART.

### ALU

La **ALU** constituye el bloque encargado del procesamiento de los datos dentro del sistema.

A diferencia de la comunicación UART, que maneja la información de manera serial, la ALU trabaja con palabras paralelas. Por este motivo, los datos recibidos deben atravesar previamente el receptor UART y el circuito de interfaz antes de poder ser utilizados por este bloque.

La comunicación permite proporcionar a la ALU los datos necesarios para realizar una operación y, una vez obtenido el resultado, entregarlo nuevamente al circuito de interfaz para que pueda ser transmitido hacia el exterior.

De esta forma, la UART funciona como el medio de comunicación de entrada y salida, mientras que la ALU permanece como el bloque encargado de realizar el procesamiento de la información.

### Integración del sistema

Considerando todos los módulos en conjunto, el funcionamiento comienza con la llegada de información mediante la línea `RX`.

El receptor UART utiliza los ticks provenientes del Baud Rate Generator para identificar correctamente el comienzo de una trama y muestrear los bits recibidos. Una vez completada la recepción, la información queda disponible como una palabra paralela.

El circuito de interfaz recibe estos datos y coordina su transferencia hacia la ALU. Una vez que se dispone de la información necesaria, la ALU realiza el procesamiento correspondiente y genera un resultado.

Posteriormente, dicho resultado vuelve a atravesar el circuito de interfaz, que coordina su entrega al transmisor UART. El transmisor convierte entonces el dato paralelo nuevamente en una trama serial y lo envía hacia el exterior mediante la línea `TX`.

El flujo general de información puede representarse como:

`RX → Receptor UART → Circuito de interfaz → ALU → Circuito de interfaz → Transmisor UART → TX`

El Baud Rate Generator proporciona en paralelo la referencia temporal necesaria para los módulos UART.

De esta manera, el sistema completo permite recibir información serial, transformarla en datos utilizables internamente, procesarla mediante la ALU y transmitir nuevamente el resultado a través de una comunicación UART.

![Arquitectura completa del sistema UART y ALU](images/diagrama-completo.png)

*Figura 2. Integración del sistema completo: Baud Rate Generator, receptor UART, transmisor UART, circuito de interfaz y ALU.*

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






## 6. Pruebas en placa


https://github.com/user-attachments/assets/f8cefe6b-41c8-45ba-811f-dfc6756e5fc6






